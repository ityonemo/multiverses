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

  use Multiverses.MacroClone,
    module: DynamicSupervisor,
    except: [start_child: 2]

  defclone start_child(supervisor, spec) do
    universe = Multiverses.link()

    bootstrap = fn {m, f, a} -> {:erlang, :apply, [
      fn ->
        Multiverses.port(universe)
        res = :erlang.apply(m, f, a)
        Multiverses.drop()
        res
      end, []]}
    end

    child = spec
    |> fn
      {_, _, _, _, _, _} -> spec
      any -> Supervisor.child_spec(spec, [])
    end.()
    |> fn
      {_, mfa, restart, shutdown, type, modules} ->
        {bootstrap.(mfa), restart, shutdown, type, modules}
      spec_map = %{start: {mod, _, _}}  ->
        restart = Map.get(spec_map, :restart, :permanent)
        type = Map.get(spec_map, :type, :worker)
        modules = Map.get(spec_map, :modules, [mod])
        shutdown = case type do
          :worker -> Map.get(spec_map, :shutdown, 5_000)
          :supervisor -> Map.get(spec_map, :shutdown, :infinity)
        end

        {bootstrap.(spec_map.start), restart, shutdown, type, modules}
    end.()

    GenServer.call(supervisor, {:start_child, child})
  end
end
