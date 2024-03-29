import MultiversesTest.Replicant

defmoduler MultiversesTest.Application.PutTest do
  use ExUnit.Case, async: true

  @application Multiverses.Application

  setup do
    Multiverses.shard(Application)
  end

  describe "basic Application.put_env/3 sets an env variable" do
    test "that can be retrieved" do
      @application.put_env(:multiverses, :foo, :bar)
      assert :bar == @application.get_env(:multiverses, :foo)
    end

    test "default elixir get_env doesn't see it" do
      @application.put_env(:multiverses, :foo, :bar)
      assert nil == Elixir.Application.get_env(:multiverses, :foo)
    end
  end

  describe "when another process puts an env variable" do
    test "it's invisible if it's in another universe" do
      test_pid = self()

      spawn(fn ->
        Multiverses.shard(Application)
        @application.put_env(:multiverses, :foo, :bar)
        send(test_pid, :unblock)
      end)

      assert_receive :unblock, 500
      assert nil == Elixir.Application.get_env(:multiverses, :foo)
    end

    test "it's visible if it's in the same universe" do
      fn ->
        @application.put_env(:multiverses, :foo, :bar)
      end
      |> Task.async()
      |> Task.await()

      assert nil == Elixir.Application.get_env(:multiverses, :foo)
    end
  end
end
