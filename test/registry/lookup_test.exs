import MultiversesTest.Replicant

defmoduler MultiversesTest.Registry.LookupTest do
  use Multiverses, with: Registry

  use ExUnit.Case, async: true

  alias MultiversesTest.Registry.TestServer

  test "registry.lookup/2" do
    test_pid = self()

    reg = test_pid |> inspect |> String.to_atom
    {:ok, _reg} = Registry.start_link(keys: :unique, name: reg)

    {:ok, outer_srv} = TestServer.start_link(reg, :foo)

    spawn_link(fn ->
      {:ok, inner_srv} = TestServer.start_link(reg, :foo)

      assert Registry.lookup(reg, :foo) == [{inner_srv, nil}]

      send(test_pid, :inner_started)
      receive do :hold_open -> :ok end
    end)

    receive do :inner_started -> :ok end

    assert Registry.lookup(reg, :foo) == [{outer_srv, nil}]
  end
end
