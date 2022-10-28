defmodule Multiverses.AppSupervisor do
  @moduledoc """
  AppSupervisor is the core `Application` module that supervises the `Multiverses.Server` module,
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
  @spec shard(module) :: [{module, Multiverse.id}]
  @spec shards(pid) :: [{module, Multiverse.id()}]
  @spec id(module, keyword) :: Multiverse.id()
  @spec allow(module, pid | Multiverse.id(), term) :: :ok
  @spec all(module) :: [Multiverse.id()]
  @spec clear(module) :: :ok

  # private api
  @spec id_pair(module) :: {pid, Multiverse.id()} | nil
  @spec id_pair(:ets.table(), module, [pid]) :: {pid, Multiverse.id()} | nil

  # STARTUP BOILERPLATE
  def start_link(_) do
    case GenServer.start_link(__MODULE__, [], name: __MODULE__) do
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
    this = self()
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

    result = GenServer.call(__MODULE__, {:shard, modules, this})

    Node.list
    |> Task.async_stream(fn node ->
      :rpc.call(node, __MODULE__, :_import, [result])
    end)
    |> Stream.run

    result
  end

  def shards(pid) do
    :ets.select(__MODULE__, [
      {{{:"$1", :"$2"}, :"$3"}, [{:==, :"$2", {:const, pid}}], [{{:"$1", :"$3"}}]}
    ])
  end

  defp shard_impl(modules, pid, _from, table) do
    tuples = Enum.map(modules, &{{&1, pid}, :erlang.phash2({&1, pid})})
    :ets.insert(table, tuples)
    {:reply, tuples, table}
  end

  def id(module, options) do
    pair = id_pair(module)
    strict = Keyword.get(options, :strict, true)

    unless not strict or pair do
      raise UnexpectedCallError,
            "no shard defined for module #{inspect(module)} in #{format_process()}"
    end

    elem(pair, 1)
  end

  defp id_pair(module) do
    callers = [self() | Process.get(:"$callers", [])]
    id_pair(__MODULE__, module, callers)
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
    case GenServer.call(__MODULE__, {:allow, module, owner, allow}) do
      :ok ->
        :ok

      :error ->
        raise "Multiverses.allow/3 attempted to find the shard of #{inspect(owner)} but there was none"
    end
  end

  def _import(imports) do
    GenServer.call(__MODULE__, {:_import, imports})
  end

  defp _import_impl(imports, _from, table) do
    :ets.insert(table, imports)
    {:reply, :ok, table}
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

  def all(module) do
    __MODULE__
    |> :ets.select([{{{:"$1", :_}, :"$2"}, [{:==, :"$1", module}], [:"$2"]}])
    |> Enum.uniq()
  end

  def clear(module), do: GenServer.call(__MODULE__, {:clear, module, self()})

  defp clear_impl(module, who, _from, table) do
    :ets.delete(table, {module, who})
    {:reply, :ok, table}
  end

  def _dump, do: GenServer.call(__MODULE__, :dump)

  defp dump_impl(_from, table),
    do: {:reply, :ets.select(table, [{{:"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}]), table}

  # ROUTER

  def handle_call({:shard, module, pid}, from, table),
    do: shard_impl(module, pid, from, table)

  def handle_call({:allow, module, owner, allowed}, from, table),
    do: allow_impl(module, owner, allowed, from, table)

  def handle_call({:_import, imports}, from, table), do: _import_impl(imports, from, table)

  def handle_call(:dump, from, table), do: dump_impl(from, table)

  def handle_call({:clear, module, who}, from, table), do: clear_impl(module, who, from, table)

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
