import MultiversesTest.Replicant

defmoduler MultiversesTest.Application.ClusterTest do
  use ExUnit.Case, async: true

  require Peer

  test "if you shard locally an rpc can see it" do
    this = self()
    [{_, universe_id}] = Multiverses.shard(Application)

    assert [{Application, universe_id}] == (Peer.call([this: this]) do
      Multiverses.shards(this)
    end)
  end

  test "if you shard remotely, we can see it locally" do
    this = self()

    remote_pid = Peer.call([this: this]) do
      spawn(fn ->
        send(this, {:shards, Multiverses.shard(Application)})
        receive do :hold -> :open end
      end)
    end

    assert_receive {:shards, [{{Application, ^remote_pid}, universe_id}]}

    assert [{Application, universe_id}] == Multiverses.shards(remote_pid)
  end
end
