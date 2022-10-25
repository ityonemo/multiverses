import MultiversesTest.Replicant

defmodule MultiversesTest.DynamicSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmoduler MultiversesTest.DynamicSupervisor.UsingTest do
  use ExUnit.Case, async: true

  alias MultiversesTest.BasicGenServer, as: TestServer

  @dynamic_supervisor Multiverses.DynamicSupervisor

  test "multiverse dynamic supervisors label genservers correctly" do
    test_pid = self()
    {:ok, sup} = @dynamic_supervisor.start_link(strategy: :one_for_one)

    {:ok, outer_child} = @dynamic_supervisor.start_child(sup, {TestServer, forward_callers: true})

    inner_universe =
      spawn(fn ->
        {:ok, inner_child} =
          @dynamic_supervisor.start_child(sup, {TestServer, forward_callers: true})

        send(test_pid, {:inner_child, inner_child})

        receive do
          :hold -> :open
        end
      end)

    inner_child =
      receive do
        {:inner_child, inner_child} -> inner_child
      end

    assert inner_universe == TestServer.get_universe(inner_child)
    assert test_pid == TestServer.get_universe(outer_child)
  end
end
