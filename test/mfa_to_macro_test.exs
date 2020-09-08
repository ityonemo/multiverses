defmodule MultiversesTest.Clone.MfaToDefdelegateTest do
  use ExUnit.Case, async: true

  alias Multiverses.Clone

  def formatted(code), do: code |> Code.format_string! |> IO.iodata_to_binary

  describe "mfa_to_macro/1" do
    test "works on zero arity function" do
      assert formatted("""
      defdelegate(bar, to: Foo)
      """) == Foo
      |> Clone.mfa_to_defdelegate({:bar, 0})
      |> Macro.to_string
      |> formatted
    end

    test "works on one arity function" do
      assert formatted("""
      defdelegate(bar(p1), to: Foo)
      """) == Foo
      |> Clone.mfa_to_defdelegate({:bar, 1})
      |> Macro.to_string
      |> formatted
    end
  end

end
