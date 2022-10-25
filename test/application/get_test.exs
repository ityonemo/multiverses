import MultiversesTest.Replicant

defmoduler MultiversesTest.Application.GetTest do
  use ExUnit.Case, async: true

  @application Multiverses.Application

  # see test_helper.exs for the :global environment variable

  describe "basic Application.get_env/2 gets an env variable" do
    test "that was set by the global environment system" do
      assert :value == @application.get_env(:multiverses, :global)
    end

    test "that was set locally" do
      @application.put_env(:multiverses, :global, :overlay)
      assert :overlay == @application.get_env(:multiverses, :global)
    end

    test "and reports nil if it doesn't exist" do
      assert nil == @application.get_env(:multiverses, nil)
    end
  end

  describe "when a change came from another process, Application.get_env/2" do
    test "can see an overlay from the same universe" do
      fn ->
        @application.put_env(:multiverses, :global, :overlay)
      end
      |> Task.async
      |> Task.await

      assert :overlay == @application.get_env(:multiverses, :global)
    end

    test "can't see an overlay set in a different universe" do
      test_pid = self()

      spawn fn ->
        @application.put_env(:multiverses, :global, :overlay)
        send(test_pid, :unblock)
      end

      assert_receive :unblock

      assert :value == @application.get_env(:multiverses, :global)
    end
  end

  describe "basic Application.get_env/3 gets an env variable" do
    test "that was set by the global environment system" do
      assert :value == @application.get_env(:multiverses, :global, :foo)
    end

    test "that was set locally" do
      @application.put_env(:multiverses, :global, :overlay)
      assert :overlay == @application.get_env(:multiverses, :global, :foo)
    end

    test "and reports the default value if neither exists" do
      assert :foo == @application.get_env(:multiverses, nil, :foo)
    end
  end
end
