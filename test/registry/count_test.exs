import MultiversesTest.Replicant

defmoduler MultiversesTest.Registry.CountTest do
  @registry Multiverses.Registry

  use ExUnit.Case, async: true

  alias MultiversesTest.Registry.TestServer

  test "registry.count/1" do
    Multiverses.shard(Registry)

    test_pid = self()

    reg = test_pid |> inspect |> String.to_atom()
    {:ok, _reg} = @registry.start_link(keys: :unique, name: reg)

    assert 0 == @registry.count(reg)
    {:ok, _} = TestServer.start_link(reg, :foo)
    Process.sleep(100)
    assert 1 == @registry.count(reg)

    spawn_link(fn ->
      Multiverses.shard(Registry)

      assert 0 == @registry.count(reg)

      {:ok, _} = TestServer.start_link(reg, :foo)

      assert 1 == @registry.count(reg)

      send(test_pid, :inner_started)

      receive do
        :hold_open -> :ok
      end
    end)

    receive do
      :inner_started -> :ok
    end

    assert 1 == @registry.count(reg)
  end
end
