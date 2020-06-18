defmodule MultiversesTest.TestServer do

  use Multiverses
  use GenServer

  def start_link(_) do
    link = Multiverses.link()
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

defmoduler MultiversesTest.ServerTest do
  use ExUnit.Case, async: true

  import Mox

  alias MultiversesTest.TestServer

  setup :verify_on_exit!

  describe "genservers can pass data through link/port" do
    test "transfers callers to GenServer" do
      {:ok, child} = TestServer.start_link(nil)
      assert [self()] == TestServer.get_universe(child)
    end

    test "mox calls can be multiversed" do
      test_pid = self()

      MockBench
      |> expect(:foo, 3, fn -> :bar end)

      {:ok, srv1} = TestServer.start_link(nil)
      assert :bar == TestServer.get_mox(srv1)

      spawn_link(fn ->
        # this is in a detached universe.
        MockBench
        |> expect(:foo, fn -> :baz end)

        {:ok, srv2} = TestServer.start_link(nil)
        assert :baz == TestServer.get_mox(srv2)

        send(test_pid, :unblock)
      end)

      assert :bar == TestServer.get_mox(srv1)
      receive do :unblock -> :ok end

      # show that this works, two tasks deep
      result = Task.async(fn ->
        Task.async(fn ->
          {:ok, srv3} = TestServer.start_link(nil)
          TestServer.get_mox(srv3)
        end)
        |> Task.await
      end)
      |> Task.await

      assert :bar == result
    end
  end
end
