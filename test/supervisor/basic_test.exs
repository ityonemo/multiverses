import MultiversesTest.Replicant

defmodule MultiversesTest.Supervisor do
  use Multiverses, with: Supervisor
  use Supervisor

  alias MultiversesTest.BasicGenServer, as: TestServer

  def start_link do
    Supervisor.start_link(__MODULE__, nil)
  end

  def init(_) do
    Supervisor.init([{TestServer, forward_callers: true}], strategy: :one_for_one)
  end

end

defmoduler MultiversesTest.Supervisor.BasicTest do
  use ExUnit.Case, async: true

  alias MultiversesTest.BasicGenServer, as: TestServer

  defp find_pid([{_name, pid, _type, _args}]), do: pid

  test "multiverse static supervisors label genservers correctly" do
    test_pid = self()
    {:ok, outer_sup} = MultiversesTest.Supervisor.start_link()

    outer_child = outer_sup
    |> Supervisor.which_children
    |> find_pid

    inner_universe = spawn fn ->
      {:ok, inner_sup} = MultiversesTest.Supervisor.start_link()

      inner_child = inner_sup
      |> Supervisor.which_children
      |> find_pid

      send(test_pid, {:inner_child, inner_child})
      receive do :hold -> :open end
    end

    inner_child = receive do {:inner_child, inner_child} -> inner_child end

    assert test_pid == TestServer.get_universe(outer_child)
    assert inner_universe == TestServer.get_universe(inner_child)
  end
end
