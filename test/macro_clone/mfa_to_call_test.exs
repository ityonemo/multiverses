defmodule MultiversesTest.MacroClone.MfaToCallTest do
  use ExUnit.Case, async: true

  alias Multiverses.MacroClone

  def formatted(code), do: code |> Code.format_string!

  describe "mfa_to_call/1" do
    test "works on zero arity function" do
      assert formatted("""
      Foo.bar()
      """) == {Foo, :bar, 0}
      |> MacroClone.mfa_to_call
      |> Macro.to_string
      |> formatted
    end

    test "works on one arity function" do
      assert formatted("""
      Foo.bar(unquote(p1))
      """) == {Foo, :bar, 1}
      |> MacroClone.mfa_to_call
      |> Macro.to_string
      |> formatted
    end
  end

end
