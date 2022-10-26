import MultiversesTest.Replicant

defmoduler MultiversesTest.Registry.DispatchTest do
  @registry Multiverses.Registry

  use ExUnit.Case, async: true

  alias MultiversesTest.Registry.TestServer

  test "registry.dispatch/4" do
    Multiverses.shard(Registry)
    test_pid = self()

    reg = test_pid |> inspect |> String.to_atom()
    {:ok, _reg} = @registry.start_link(keys: :unique, name: reg)

    {:ok, outer_srv} = TestServer.start_link(reg, :foo)

    spawn_link(fn ->
      Multiverses.shard(Registry)
      assert 0 == @registry.count(reg)

      {:ok, _} = TestServer.start_link(reg, :foo)

      assert 1 == @registry.count(reg)

      send(test_pid, :inner_started)

      @registry.dispatch(reg, :foo, fn entries ->
        send(test_pid, {:inner_entries, entries})
      end)

      receive do
        :hold_open -> :ok
      end
    end)

    receive do
      :inner_started -> :ok
    end

    @registry.dispatch(reg, :foo, fn entries ->
      send(test_pid, {:outer_entries, entries})
    end)

    assert_receive {:outer_entries, outer_entries}
    assert [{outer_srv, nil}] == outer_entries
    assert_receive {:inner_entries, inner_entries}
    assert [{inner_srv, nil}] = inner_entries
    assert inner_srv != outer_srv
  end
end
