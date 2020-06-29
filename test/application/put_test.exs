import MultiversesTest.Replicant

defmoduler MultiversesTest.Application.PutTest do
  use ExUnit.Case, async: true
  use Multiverses, with: Application

  describe "basic Application.put_env/3 sets an env variable" do
    test "that can be retrieved" do
      Application.put_env(:multiverses, :foo, :bar)
      assert :bar == Application.get_env(:multiverses, :foo)
    end

    test "default elixir get_env doesn't see it" do
      Application.put_env(:multiverses, :foo, :bar)
      assert nil == Elixir.Application.get_env(:multiverses, :foo)
    end
  end

  describe "when another process puts an env variable" do
    test "it's invisible if it's in another universe" do
      test_pid = self()
      spawn fn ->
        Application.put_env(:multiverses, :foo, :bar)
        send(test_pid, :unblock)
      end

      assert_receive :unblock
      assert nil == Elixir.Application.get_env(:multiverses, :foo)
    end

    test "it's visible if it's in the same universe" do
      fn ->
        Application.put_env(:multiverses, :foo, :bar)
      end
      |> Task.async
      |> Task.await

      assert nil == Elixir.Application.get_env(:multiverses, :foo)
    end
  end
end
