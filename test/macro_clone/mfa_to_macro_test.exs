defmodule MultiversesTest.MacroClone.MfaToMacroTest do
  use ExUnit.Case, async: true

  alias Multiverses.MacroClone

  def formatted(code), do: code |> Code.format_string!

  describe "mfa_to_macro/1" do
    test "works on zero arity function" do
      assert formatted("""
      defmacro(bar()) do
        quote do
          Foo.bar()
        end
      end
      """) == Foo
      |> MacroClone.mfa_to_macro({:bar, 0})
      |> Macro.to_string
      |> formatted
    end

    test "works on one arity function" do
      assert formatted("""
      defmacro(bar(p1)) do
        quote do
          Foo.bar(unquote(p1))
        end
      end
      """) == Foo
      |> MacroClone.mfa_to_macro({:bar, 1})
      |> Macro.to_string
      |> formatted
    end
  end

end
