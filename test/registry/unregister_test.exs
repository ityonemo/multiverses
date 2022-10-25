import MultiversesTest.Replicant

defmoduler MultiversesTest.Registry.UnregisterTest do
  @registry Multiverses.Registry

  use ExUnit.Case, async: true

  alias MultiversesTest.Registry.TestServer

  test "registry.unregister/2" do
    Multiverses.register(Registry)
    test_pid = self()

    reg = test_pid |> inspect |> String.to_atom()
    {:ok, _reg} = @registry.start_link(keys: :unique, name: reg)

    {:ok, outer_srv} = TestServer.start_link(reg, :foo)

    inner_pid =
      spawn_link(fn ->
        Multiverses.register(Registry)
        
        {:ok, inner_srv} = TestServer.start_link(reg, :foo)

        send(test_pid, :inner_started)

        assert 1 == @registry.count(reg)

        receive do
          :release -> :ok
        end

        TestServer.unregister(reg, inner_srv)

        Process.sleep(10)

        assert 0 == @registry.count(reg)

        send(test_pid, :inner_unregistered)
      end)

    receive do
      :inner_started -> :ok
    end

    assert 1 == @registry.count(reg)

    TestServer.unregister(reg, outer_srv)

    Process.sleep(10)

    assert 0 == @registry.count(reg)

    send(inner_pid, :release)

    assert_receive :inner_unregistered
  end
end
