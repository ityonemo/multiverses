import MultiversesTest.Replicant

defmoduler MultiversesTest.Registry.KeysTest do

  @registry Multiverses.Registry

  use ExUnit.Case, async: true

  alias MultiversesTest.Registry.TestServer

  test "registry.keys/2" do
    test_pid = self()

    reg = test_pid |> inspect |> String.to_atom
    {:ok, _reg} = @registry.start_link(keys: :unique, name: reg)

    {:ok, outer_srv} = TestServer.start_link(reg, :foo)

    spawn_link(fn ->
      {:ok, inner_srv} = TestServer.start_link(reg, :foo)

      assert @registry.keys(reg, inner_srv) == [:foo]

      send(test_pid, :inner_started)
      receive do :hold_open -> :ok end
    end)

    receive do :inner_started -> :ok end

    assert @registry.keys(reg, outer_srv) == [:foo]
  end
end
