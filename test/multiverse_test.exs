defmodule MultiversesTest do
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
  end
end
