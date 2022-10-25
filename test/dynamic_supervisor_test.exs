defmodule MultiversesTest.DynamicSupervisor.TestServer do
  use GenServer

  @dynamic_supervisor Multiverses.DynamicSupervisor

  def start_supervised(sup) do
    link = Multiverses.link()
    @dynamic_supervisor.start_child(sup, {__MODULE__, link})
  end

  def start_link(link) do
    GenServer.start_link(__MODULE__, link)
  end
  def init(link) do
    Multiverses.port(link)
    {:ok, nil}
  end

  def get_universe(server), do: GenServer.call(server, :get_universe)
  def get_mox(server), do: GenServer.call(server, :get_mox)

  def handle_call(:get_universe, _, state), do:
    {:reply, Process.get(:"$callers"), state}
  def handle_call(:get_mox, _, state), do:
    {:reply, MockBench.foo(), state}

end

import MultiversesTest.Replicant

defmoduler MultiversesTest.DynamicSupervisorTest do
  use ExUnit.Case, async: true

  @dynamic_supervisor Multiverses.DynamicSupervisor

  import Mox

  alias MultiversesTest.DynamicSupervisor.TestServer

  setup :verify_on_exit!

  setup do
    {:ok, sup} = @dynamic_supervisor.start_link(strategy: :one_for_one)
    {:ok, sup: sup}
  end

  describe "genservers can pass data through link/port" do
    test "transfers callers to GenServer", %{sup: sup} do
      {:ok, child} = TestServer.start_supervised(sup)
      assert [self()] == TestServer.get_universe(child)
    end

    test "mox calls can be multiversed", %{sup: sup} do
      test_pid = self()

      MockBench
      |> expect(:foo, 3, fn -> :bar end)

      {:ok, srv1} = TestServer.start_supervised(sup)
      assert :bar == TestServer.get_mox(srv1)

      spawn_link(fn ->
        # this is in a detached universe.
        MockBench
        |> expect(:foo, fn -> :baz end)

        {:ok, srv2} = TestServer.start_supervised(sup)
        assert :baz == TestServer.get_mox(srv2)

        send(test_pid, :unblock)
      end)

      assert :bar == TestServer.get_mox(srv1)
      receive do :unblock -> :ok end

      # show that this works, two tasks deep
      result = Task.async(fn ->
        Task.async(fn ->
          {:ok, srv3} = TestServer.start_supervised(sup)
          TestServer.get_mox(srv3)
        end)
        |> Task.await
      end)
      |> Task.await

      assert :bar == result
    end
  end
end
