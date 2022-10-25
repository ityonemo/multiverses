defmodule Multiverses.DynamicSupervisor do
  @moduledoc """
  This module is intended to be a drop-in replacement for `DynamicSupervisor`.

  It launches the supervised process during a slice of time in which the
  universe of the DynamicSupervisor is temporarily set to the universe of
  its caller.  For example, if the supervised process is `Multiverses.GenServer`,
  with `start_link` option `forward_callers: true`, then the GenServer will
  exist in the same universe as its caller.

  Currently uses DynamicSupervisor private API, so forward compatibility is
  not guaranteed.

  ## Usage

  This module should only be used at the point of starting a child under the
  supervisor.  All other uses of DynamicSupervisor (such as `use DynamicSupervisor`)
  should use the native Elixir DynamicSupervisor module, and the supervisor
  is fully compatible with native DynamicSupervisor processes.

  ## Notes

  currently, only `start_child/2` is overloaded to provide sharded information.
  `count_children/1`, `terminate_child/2` and `which_children/1` will act on
  the global information.  If you need access to partitioned collections of
  processes, use `Multiverse.Registry`.
  """

  use Multiverses.Clone,
    module: DynamicSupervisor,
    except: [start_child: 2]

  require Multiverses

  @doc "See `DynamicSupervisor.start_child/2`."
  def start_child(supervisor, spec) do
    # works by injecting a different supervisor bootstrap *through* the
    # custom `bootstrap/2` function provided in this module.

    child =
      spec
      |> to_spec_tuple
      |> inject_bootstrap(Multiverses.link())

    GenServer.call(supervisor, {:start_child, child})
  end

  defp bootstrap_for(mfa, link), do: {__MODULE__, :bootstrap, [mfa, link]}

  defp to_spec_tuple({_, _, _, _, _, _} = spec), do: spec
  defp to_spec_tuple(spec), do: Supervisor.child_spec(spec, [])

  # it's not entirely clear why this is happening here.
  @dialyzer {:nowarn_function, inject_bootstrap: 2}

  @spec inject_bootstrap(Supervisor.child_spec(), Multiverses.link()) :: Supervisor.child_spec()
  defp inject_bootstrap({_, mfa, restart, shutdown, type, modules}, link) do
    {bootstrap_for(mfa, link), restart, shutdown, type, modules}
  end

  defp inject_bootstrap(spec_map = %{start: {mod, _, _}}, link) do
    restart = Map.get(spec_map, :restart, :permanent)
    type = Map.get(spec_map, :type, :worker)
    modules = Map.get(spec_map, :modules, [mod])

    shutdown =
      case type do
        :worker -> Map.get(spec_map, :shutdown, 5_000)
        :supervisor -> Map.get(spec_map, :shutdown, :infinity)
      end

    {bootstrap_for(spec_map.start, link), restart, shutdown, type, modules}
  end

  @doc false
  def bootstrap({m, f, a}, universe) do
    Multiverses.port(universe)
    res = :erlang.apply(m, f, a)
    Multiverses.drop()
    res
  end
end
