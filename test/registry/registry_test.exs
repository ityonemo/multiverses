defmodule MultiversesTest.Registry.TestServer do
  use Multiverses, with: Registry

  use GenServer

  def start_link(reg, name) do
    link = Multiverses.link()
    GenServer.start_link(__MODULE__, {reg, name, link})
  end

  def init({reg, name, link}) do
    Multiverses.port(link)
    Registry.register(reg, name, nil)
    {:ok, nil}
  end
end

import MultiversesTest.Replicant

defmoduler MultiversesTest.RegistryTest do
  use Multiverses, with: Registry

  use ExUnit.Case, async: true

  alias MultiversesTest.Registry.TestServer

  describe "Registry registries" do
    test "store sharded views of state" do
      test_pid = self()

      reg = test_pid |> inspect |> String.to_atom
      {:ok, _reg} = Elixir.Registry.start_link(keys: :unique, name: reg)

      {:ok, foo} = TestServer.start_link(reg, :foo)

      spawn_link(fn ->
        # make sure we can't see foo
        assert nil == Registry.get(reg, :foo)

        {:ok, bar} = TestServer.start_link(reg, :bar)

        assert bar == Registry.get(reg, :bar)
        assert [bar] == Registry.all(reg)

        send(test_pid, :bar_started)

        receive do :hold_open -> :ok end
      end)

      receive do :bar_started -> :ok end
      assert nil == Registry.get(reg, :bar)
      assert foo == Registry.get(reg, :foo)

      assert [foo] = Registry.all(reg)
    end

    test "work with shared names" do
      test_pid = self()

      reg = test_pid |> inspect |> String.to_atom
      {:ok, _reg} = Elixir.Registry.start_link(keys: :duplicate, name: reg)

      {:ok, foo} = TestServer.start_link(reg, :foo)

      spawn_link(fn ->
        # make sure we can't see foo
        assert nil == Registry.get(reg, :foo)

        {:ok, foo_inner} = TestServer.start_link(reg, :foo)

        assert foo_inner == Registry.get(reg, :foo)
        assert [foo_inner] == Registry.all(reg)

        send(test_pid, :inner_started)

        receive do :hold_open -> :ok end
      end)

      receive do :inner_started -> :ok end
      assert nil == Registry.get(reg, :bar)
      assert foo == Registry.get(reg, :foo)

      assert [foo] = Registry.all(reg)
    end
  end
end
