import MultiversesTest.Replicant

defmoduler MultiversesTest.GenServerTest do
  use ExUnit.Case, async: true

  alias MultiversesTest.BasicGenServer, as: TestServer

  test "multiverse gen_servers are correctly branded" do
    test_pid = self()
    {:ok, srv} = TestServer.start_link(nil)

    inner_universe = spawn fn ->
      {:ok, inner_srv} = TestServer.start_link(nil)
      send(test_pid, {:inner_srv, TestServer.get_universe(inner_srv)})
    end

    assert self() == TestServer.get_universe(srv)
    assert self() != inner_universe
    assert_receive {:inner_srv, ^inner_universe}
  end
end
