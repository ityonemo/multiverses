import MultiversesTest.Replicant

defmoduler MultiversesTest.Registry.DispatchTest do
  use Multiverses, with: Registry

  use ExUnit.Case, async: true

  alias MultiversesTest.Registry.TestServer

  test "registry.dispatch/4" do
    test_pid = self()

    reg = test_pid |> inspect |> String.to_atom
    {:ok, _reg} = Registry.start_link(keys: :unique, name: reg)

    {:ok, outer_srv} = TestServer.start_link(reg, :foo)

    spawn_link(fn ->
      assert 0 == Registry.count(reg)

      {:ok, _} = TestServer.start_link(reg, :foo)

      assert 1 == Registry.count(reg)

      send(test_pid, :inner_started)

      Registry.dispatch(reg, :foo, fn entries ->
        send(test_pid, {:inner_entries, entries})
      end)

      receive do :hold_open -> :ok end
    end)

    receive do :inner_started -> :ok end

    Registry.dispatch(reg, :foo, fn entries ->
      send(test_pid, {:outer_entries, entries})
    end)

    assert_receive {:outer_entries, outer_entries}
    assert [{outer_srv, nil}] == outer_entries
    assert_receive {:inner_entries, inner_entries}
    assert [{inner_srv, nil}] = inner_entries
    assert inner_srv != outer_srv
  end
end
