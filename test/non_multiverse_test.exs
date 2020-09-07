defmodule MultiversesTest.NonMultiverseTest do
  use ExUnit.Case

  # makes sure that we can `use Multiverse` for a nonexistent module
  # when we have Multiverses disabled.

  setup_all do
    Application.put_env(:multiverses, :use_multiverses, false)
    on_exit(fn ->
      Application.put_env(:multiverses, :use_multiverses, true)
    end)
  end

  test "use Multiverses no-ops when Multiverses is disabled" do
    __DIR__
    |> Path.join("_assets/non_multiverse.exs")
    |> Code.compile_file()
  end

end
