import MultiversesTest.Replicant

defmoduler MultiversesTest.Application.DeleteTest do
  use ExUnit.Case, async: true

  @application Multiverses.Application

  # see test_helper.exs for the :global environment variable

  describe "basic Application.delete_env/2 deletes an env variable" do
    test "that was set by the global environment system" do
      @application.delete_env(:multiverses, :global)
      assert :error == @application.fetch_env(:multiverses, :global)
    end

    test "but native Elixir Application doesn't see this change" do
      @application.delete_env(:multiverses, :global)
      assert {:ok, :value} = Application.fetch_env(:multiverses, :global)
    end

    test "and is consistent even if the value didn't exist in the first place" do
      @application.delete_env(:multiverses, nil)
      assert :error = @application.fetch_env(:multiverses, nil)
    end
  end

  describe "when a change came from another process, Application.delete_env/2" do
    test "can see an deletion done in the same universe" do
      fn ->
        @application.delete_env(:multiverses, :global)
      end
      |> Task.async
      |> Task.await

      assert :error == @application.fetch_env(:multiverses, :global)
    end

    test "can't see an deletion done in a different universe" do
      test_pid = self()

      spawn fn ->
        @application.delete_env(:multiverses, :global)
        send(test_pid, :unblock)
      end

      assert_receive :unblock

      assert :value == @application.get_env(:multiverses, :global)
    end
  end

end
