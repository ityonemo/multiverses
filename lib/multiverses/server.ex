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
  use GenServer

  # API
  @spec register(module) :: :ok
  @spec token(module) :: Multiverse.token()
  @spec allow(module, pid | Multiverse.token(), term) :: :ok

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

  def register(module) do
    GenServer.call(@this, {:register, module, self()})
  end

  defp register_impl(module, pid, _from, table) do
    token = :erlang.phash2({module, pid})
    :ets.insert(table, {{module, pid}, token})
    {:reply, :ok, table}
  end

  def token(module) do
    callers = [self() | Process.get(:"$callers", [])]

    if node(:global.whereis_name(__MODULE__)) === node() do
      get_token(__MODULE__, module, callers)
    else
      GenServer.call(@this, {:token, module, callers})
    end
  end

  defp token_impl(module, callers, _from, table) do
    {:reply, get_token(table, module, callers), table}
  end

  defp get_token(table, module, callers) do
    :ets.select(table, [{{:"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}])

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

    [{{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", module}, callers_chain], [:"$3"]}]
  end

  def allow(module, owner, allow),
    do: GenServer.call(@this, {:allow, module, owner, allow})

  defp allow_impl(module, owner, allow, _from, table) do
    allow_pid = to_pid(allow)

    result =
      with owner_pid when is_pid(owner_pid) <- owner,
           selection = [
             {{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", module}, {:==, :"$2", {:const, owner_pid}}],
              [:"$3"]}
           ],
           [token] <- :ets.select(table, selection) do
        :ets.insert(table, {{module, allow_pid}, token})
        :ok
      else
        token when is_integer(token) ->
          :ets.insert(table, {{module, allow_pid}, token})
          :ok

        [] ->
          # TODO: punt this to a not found error.
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

  def handle_call({:register, module, pid}, from, table),
    do: register_impl(module, pid, from, table)

  def handle_call({:token, module, callers}, from, table),
    do: token_impl(module, callers, from, table)

  def handle_call({:allow, module, owner, allowed}, from, table),
    do: allow_impl(module, owner, allowed, from, table)

  def handle_call(:dump, from, table), do: dump_impl(from, table)
end
