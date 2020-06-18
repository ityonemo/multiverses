import MultiversesTest.Replicant

defmoduler MultiversesTest.Registry.SelectTest do
  use Multiverses, with: Registry

  use ExUnit.Case, async: true

  alias MultiversesTest.Registry.TestServer

  test "registry.lookup/2" do
    test_pid = self()

    reg = test_pid |> inspect |> String.to_atom
    {:ok, _reg} = Registry.start_link(keys: :unique, name: reg)

    {:ok, outer_srv} = TestServer.start_link(reg, :foo)

    spawn_link(fn ->
      {:ok, _inner_srv} = TestServer.start_link(reg, :foo)
      send(test_pid, :inner_started)
      receive do :hold_open -> :ok end
    end)

    receive do :inner_started -> :ok end

    assert [true] == Registry.select(reg, [{
      {:_, :_, :_}, [], [true]
    }])

    assert [outer_srv] == Registry.select(reg, [{
      {:_, :"$1", :_}, [], [:"$1"]
    }])

    assert [:foo] == Registry.select(reg, [{
      {:"$1", :_, :_}, [], [:"$1"]
    }])

    assert [outer_srv] == Registry.select(reg, [{
      {:"$1", :"$2", :_}, [{:==, :"$1", {:const, :foo}}], [:"$2"]
    }])

    assert [foo: outer_srv] == Registry.select(reg, [{
      {:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]
    }])

    assert [%{key: :foo, val: outer_srv}] == Registry.select(reg, [{
      {:"$1", :"$2", :_}, [], [%{key: :"$1", val: :"$2"}]
    }])
  end
end
