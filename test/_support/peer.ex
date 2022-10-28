defmodule Peer do
  defmacro call(bindings \\ [], do: block) do
    fun_block = Macro.escape(quote do
      fun = fn ->
        unquote(block)
      end
      fun.()
    end)

    quote bind_quoted: [fun_block: fun_block, bindings: bindings] do
      Node.list()
      |> List.first
      |> :rpc.call(Code, :eval_quoted, [fun_block, bindings, __ENV__])
      |> elem(0)
    end
  end
end
