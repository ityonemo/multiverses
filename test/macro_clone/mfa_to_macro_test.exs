defmodule MultiversesTest.MacroClone.MfaToMacroTest do
  use ExUnit.Case, async: true

  alias Multiverses.MacroClone

  def formatted(code), do: code |> Code.format_string! |> IO.iodata_to_binary

  describe "mfa_to_macro/1" do
    test "works on zero arity function" do
      assert formatted("""
      [@doc("cloned from `Foo.bar/0`"),
      defmacro(bar()) do
        quote do
          Foo.bar()
        end
      end]
      """) == Foo
      |> MacroClone.mfa_to_macro({:bar, 0})
      |> Macro.to_string
      |> formatted
    end

    test "works on one arity function" do
      assert formatted("""
      [@doc("cloned from `Foo.bar/1`"),
      defmacro(bar(p1)) do
        quote do
          Foo.bar(unquote(p1))
        end
      end]
      """) == Foo
      |> MacroClone.mfa_to_macro({:bar, 1})
      |> Macro.to_string
      |> formatted
    end
  end

end
