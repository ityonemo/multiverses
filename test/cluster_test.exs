import MultiversesTest.Replicant

defmoduler MultiversesTest.Application.ClusterTest do
  use ExUnit.Case, async: true

  require Peer

  test "if you shard locally an rpc can see it" do
    this = self()
    [{_, shard_id}] = Multiverses.shard(Application)

    assert [{Application, shard_id}] ==
             (Peer.call this: this do
                Multiverses.shards(this)
              end)
  end

  test "if you shard remotely, we can see it locally" do
    this = self()

    remote_pid =
      Peer.call this: this do
        spawn(fn ->
          send(this, {:shards, Multiverses.shard(Application)})

          receive do
            :hold -> :open
          end
        end)
      end

    assert_receive {:shards, [{{Application, ^remote_pid}, shard_id}]}

    assert [{Application, shard_id}] == Multiverses.shards(remote_pid)
  end

  test "if you allow remotely, we can see it locally" do
    this = self()
    [{{Application, _}, shard_id}] = Multiverses.shard(Application)

    remote_pid =
      Peer.call this: this, shard_id: shard_id do
        spawn(fn ->
          send(this, {:shards, Multiverses.allow(Application, shard_id, self())})

          receive do
            :hold -> :open
          end
        end)
      end

    assert_receive {:shards, [{{Application, ^remote_pid}, shard_id}]}

    assert [{Application, shard_id}] == Multiverses.shards(remote_pid)
  end

  test "if you allow multiple remotely, you can see it locally" do
    this = self()

    shard_spec =
      [Application, Registry]
      |> Multiverses.shard()
      |> Enum.map(fn {{mod, _pid}, shard_id} -> {mod, shard_id} end)

    remote_pid =
      Peer.call this: this, shard_spec: shard_spec do
        spawn(fn ->
          Multiverses.allow(shard_spec, self())
          send(this, :unblock)

          receive do
            :hold -> :open
          end
        end)
      end

    assert_receive :unblock

    assert Enum.sort(shard_spec) == Enum.sort(Multiverses.shards(remote_pid))
  end
end
