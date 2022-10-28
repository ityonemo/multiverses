import MultiversesTest.Replicant

defmoduler MultiversesTest do
  use ExUnit.Case, async: true

  alias Multiverses.UnexpectedCallError

  describe "when you haven't sharded into a multiverse" do
    test "attempting to obtain the multiverse id will cause a crash" do
      assert_raise UnexpectedCallError, fn ->
        Multiverses.id(Application)
      end
    end
  end

  describe "when you try to register the same shard more than once" do
    test "it will cause a crash" do
      Multiverses.shard(Application)

      assert_raise UnexpectedCallError, fn ->
        Multiverses.shard(Application)
      end
    end
  end

  describe "you can shard on more than one module" do
    test "and it will assign both" do
      Multiverses.shard([Application, Registry])

      assert Multiverses.id(Application)
      assert Multiverses.id(Registry)
    end

    test "and both will be known to the shards function" do
      Multiverses.shard([Application, Registry])

      assert [{Application, application_id}, {Registry, registry_id}] =
               Enum.sort(Multiverses.shards())

      assert application_id == Multiverses.id(Application)
      assert registry_id == Multiverses.id(Registry)
    end
  end

  describe "the allow function" do
    test "puts a pid into a shard, by pid reference" do
      this = self()
      assert [{_, shard_id}] = Multiverses.shard(Application)

      spawned =
        spawn(fn ->
          Multiverses.allow(Application, this, self())

          assert [{Application, shard_id}] == Multiverses.shards()

          send(this, :unblock)

          receive do
            :hold -> :open
          end
        end)

      assert_receive :unblock

      assert [{Application, shard_id}] == Multiverses.shards(spawned)
    end

    test "puts a pid into a shard, by shard id" do
      this = self()
      assert [{_, shard_id}] = Multiverses.shard(Application)

      spawned =
        spawn(fn ->
          Multiverses.allow(Application, shard_id, self())

          assert [{Application, shard_id}] == Multiverses.shards()

          send(this, :unblock)

          receive do
            :hold -> :open
          end
        end)

      assert_receive :unblock

      assert [{Application, shard_id}] == Multiverses.shards(spawned)
    end

    test "using a list" do
      this = self()
      assert shard_info = Multiverses.shard([Application, Registry])

      spawned =
        spawn(fn ->
          Multiverses.allow(shard_info, self())

          assert Enum.sort(shard_info) == Enum.sort(Multiverses.shards())

          send(this, :unblock)

          receive do
            :hold -> :open
          end
        end)

      assert_receive :unblock

      assert Enum.sort(shard_info) == Enum.sort(Multiverses.shards(spawned))
    end
  end
end
