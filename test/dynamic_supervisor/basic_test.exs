import MultiversesTest.Replicant

defmoduler MultiversesTest.DynamicSupervisor.BasicTest do
  use ExUnit.Case, async: true

  alias MultiversesTest.BasicGenServer, as: TestServer

  use Multiverses, with: DynamicSupervisor

  test "multiverse dynamic supervisors label genservers correctly" do

    test_pid = self()
    {:ok, sup} = DynamicSupervisor.start_link(strategy: :one_for_one)
    {:ok, outer_child} = DynamicSupervisor.start_child(sup, TestServer)

    inner_universe = spawn fn ->
      {:ok, inner_child} = DynamicSupervisor.start_child(sup, TestServer)

      send(test_pid, {:inner_child, inner_child})
      receive do :hold -> :open end
    end

    inner_child = receive do {:inner_child, inner_child} -> inner_child end

    assert inner_universe == TestServer.get_universe(inner_child)
    assert test_pid == TestServer.get_universe(outer_child)
  end
end
