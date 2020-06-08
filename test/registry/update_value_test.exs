import MultiversesTest.Replicant

defmoduler MultiversesTest.Registry.UpdateValueTest do
  use Multiverses, with: Registry, only: :test

  use ExUnit.Case, async: true

  alias MultiversesTest.Registry.TestServer

  test "registry.update_value/2" do
    test_pid = self()

    reg = test_pid |> inspect |> String.to_atom
    {:ok, _reg} = Registry.start_link(keys: :unique, name: reg)

    {:ok, outer_srv} = TestServer.start_link(reg, :foo)

    spawn_link(fn ->
      {:ok, inner_srv} = TestServer.start_link(reg, :foo)

      assert Registry.lookup(reg, :foo) == [{inner_srv, nil}]

      TestServer.update(reg, inner_srv, fn nil -> :bar end)

      assert Registry.lookup(reg, :foo) == [{inner_srv, :bar}]

      send(test_pid, :inner_started)
      receive do :hold_open -> :ok end
    end)

    receive do :inner_started -> :ok end

    assert Registry.lookup(reg, :foo) == [{outer_srv, nil}]

    TestServer.update(reg, outer_srv, fn nil -> :baz end)

    assert Registry.lookup(reg, :foo) == [{outer_srv, :baz}]
  end
end
