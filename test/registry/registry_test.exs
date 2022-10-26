import MultiversesTest.Replicant

defmoduler MultiversesTest.RegistryTest do
  @registry Multiverses.Registry

  use ExUnit.Case, async: true

  alias MultiversesTest.Registry.TestServer

  defp get(registry, key) do
    registry
    |> @registry.select([{{:"$1", :"$2", :_}, [{:==, :"$1", {:const, key}}], [:"$2"]}])
    |> case do
      [pid] -> pid
      [] -> nil
    end
  end

  defp all(registry) do
    @registry.select(registry, [{{:_, :"$2", :_}, [], [:"$2"]}])
  end

  describe "Registry registries" do
    test "store sharded views of state" do
      Multiverses.shard(Registry)
      test_pid = self()

      reg = test_pid |> inspect |> String.to_atom()
      {:ok, _reg} = @registry.start_link(keys: :unique, name: reg)

      {:ok, foo} = TestServer.start_link(reg, :foo)

      spawn_link(fn ->
        Multiverses.shard(Registry)
        # make sure we can't see foo
        assert nil == get(reg, :foo)

        {:ok, bar} = TestServer.start_link(reg, :bar)

        assert bar == get(reg, :bar)
        assert [bar] == all(reg)

        send(test_pid, :bar_started)

        receive do
          :hold_open -> :ok
        end
      end)

      receive do
        :bar_started -> :ok
      end

      assert nil == get(reg, :bar)
      assert foo == get(reg, :foo)

      assert [^foo] = all(reg)
    end

    test "work with shared names" do
      Multiverses.shard(Registry)
      test_pid = self()

      reg = test_pid |> inspect |> String.to_atom()
      {:ok, _reg} = @registry.start_link(keys: :duplicate, name: reg)

      {:ok, foo} = TestServer.start_link(reg, :foo)

      spawn_link(fn ->
        Multiverses.shard(Registry)
        # make sure we can't see foo
        assert nil == get(reg, :foo)

        {:ok, foo_inner} = TestServer.start_link(reg, :foo)

        # assert foo_inner == get(reg, :foo)
        assert [foo_inner] == all(reg)

        send(test_pid, :inner_started)

        receive do
          :hold_open -> :ok
        end
      end)

      receive do
        :inner_started -> :ok
      end

      assert nil == get(reg, :bar)
      assert foo == get(reg, :foo)

      assert [^foo] = all(reg)
    end
  end
end
