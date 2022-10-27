defmodule Multiverses.AppSupervisor do
  @moduledoc """
  This is the core `Application` module that supervises the `Multiverses.Server` module,
  which should be running in active `Multiverses` environments.
  """

  use Application

  alias Multiverses.Server

  def start(_type, _args) do
    Supervisor.start_link([Server], strategy: :one_for_one, name: __MODULE__)
  end
end

defmodule Multiverses.Server do
  @moduledoc "core server for managing multiverse partitions"

  alias Multiverses.UnexpectedCallError

  use GenServer

  # API
  @spec shard(module) :: :ok
  @spec id(module) :: Multiverse.id()
  @spec allow(module, pid | Multiverse.id(), term) :: :ok

  # private api
  @spec id_pair(module) :: {pid, Multiverse.id()} | nil
  @spec id_pair(:ets.table(), module, [pid]) :: {pid, Multiverse.id()} | nil

  @this {:global, __MODULE__}

  # STARTUP BOILERPLATE
  def start_link(_) do
    case GenServer.start_link(__MODULE__, [], name: @this) do
      {:error, {:already_started, _}} -> :ignore
      response -> response
    end
  end

  def init(_) do
    ref = :ets.new(__MODULE__, [:named_table, :set, :protected, read_concurrency: true])
    {:ok, ref}
  end

  # API IMPLEMENTATIONS

  def shard(module_or_modules) do
    modules = List.wrap(module_or_modules)

    # check to make sure that the shard isn't already assigned.
    Enum.each(modules, fn module ->
      case id_pair(module) do
        nil ->
          :ok

        {pid, _} ->
          raise UnexpectedCallError,
                "Multiverse shard for #{inspect(module)} already exists for pid #{inspect(self())}#{format_pid_name(pid)}"
      end
    end)

    GenServer.call(@this, {:shard, modules, self()})
  end

  defp shard_impl(modules, pid, _from, table) do
    tuples = Enum.map(modules, &{{&1, pid}, :erlang.phash2({&1, pid})})
    :ets.insert(table, tuples)
    {:reply, :ok, table}
  end

  def id(module) do
    pair =
      id_pair(module) ||
        raise UnexpectedCallError,
              "no shard defined for module #{inspect(module)} in #{format_process()}"

    elem(pair, 1)
  end

  defp id_pair(module) do
    callers = [self() | Process.get(:"$callers", [])]

    if node(:global.whereis_name(__MODULE__)) === node() do
      id_pair(__MODULE__, module, callers)
    else
      GenServer.call(@this, {:id_pair, module, callers})
    end
  end

  defp id_pair_impl(module, callers, _from, table) do
    {:reply, id_pair(table, module, callers), table}
  end

  defp id_pair(table, module, callers) do
    table
    |> :ets.select(select(module, callers))
    |> List.first()
  end

  # generates the select matchspec from callers value
  defp select(module, callers) do
    callers_chain =
      callers
      |> Enum.map(&{:==, :"$2", &1})
      |> Enum.reduce(&{:or, &1, &2})

    [{{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", module}, callers_chain], [{{:"$2", :"$3"}}]}]
  end

  def allow(module, owner, allow) do
    case GenServer.call(@this, {:allow, module, owner, allow}) do
      :ok ->
        :ok

      :error ->
        raise "Multiverses.allow/3 attempted to find the shard of #{inspect(owner)} but there was none"
    end
  end

  defp allow_impl(module, owner, allow, _from, table) do
    allow_pid = to_pid(allow)

    result =
      with owner_pid when is_pid(owner_pid) <- owner,
           selection = [
             {{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", module}, {:==, :"$2", {:const, owner_pid}}],
              [:"$3"]}
           ],
           [id] <- :ets.select(table, selection) do
        :ets.insert(table, {{module, allow_pid}, id})
        :ok
      else
        id when is_integer(id) ->
          :ets.insert(table, {{module, allow_pid}, id})
          :ok

        [] ->
          :error
      end

    {:reply, result, table}
  end

  defp to_pid(pid) when is_pid(pid), do: pid
  defp to_pid(atom) when is_atom(atom), do: :erlang.whereis(atom)
  defp to_pid({module, key}), do: module.whereis_name(key)

  def _dump, do: GenServer.call(@this, :dump)

  defp dump_impl(_from, table),
    do: {:reply, :ets.select(table, [{{:"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}]), table}

  # ROUTER

  def handle_call({:shard, module, pid}, from, table),
    do: shard_impl(module, pid, from, table)

  def handle_call({:id_pair, module, callers}, from, table),
    do: id_pair_impl(module, callers, from, table)

  def handle_call({:allow, module, owner, allowed}, from, table),
    do: allow_impl(module, owner, allowed, from, table)

  def handle_call(:dump, from, table), do: dump_impl(from, table)

  # UTILITIES

  defp format_process do
    callers =
      :"$callers"
      |> Process.get()
      |> List.wrap()

    "process #{inspect(self())}" <>
      if Enum.empty?(callers) do
        ""
      else
        " (or in its callers #{inspect(callers)})"
      end
  end

  defp format_pid_name(pid) do
    if self() != pid, do: " (in parent #{pid})"
  end
end
