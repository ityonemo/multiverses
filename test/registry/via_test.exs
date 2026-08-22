import MultiversesTest.Replicant

defmoduler MultiversesTest.Registry.ViaTest do
  @registry Multiverses.Registry

  use ExUnit.Case, async: true

  defmodule Server do
    use GenServer
    def start_link(name), do: GenServer.start_link(__MODULE__, :ok, name: name)
    def init(:ok), do: {:ok, :ok}
    def handle_call(:ping, _from, s), do: {:reply, :pong, s}
  end

  # A `{:via, Multiverses.Registry, {reg, key}}` name must register under the
  # caller's universe (like lookup/whereis do), so the process can be found and
  # called through the same via name.
  test "via-tuple registers under the shard, so whereis/call find it" do
    Multiverses.shard(Registry)
    reg = self() |> inspect() |> String.to_atom()
    {:ok, _} = @registry.start_link(keys: :unique, name: reg)

    via = {:via, @registry, {reg, :srv}}
    {:ok, pid} = Server.start_link(via)

    assert @registry.whereis_name({reg, :srv}) == pid
    assert @registry.lookup(reg, :srv) == [{pid, nil}]
    assert GenServer.call(via, :ping) == :pong
  end
end
