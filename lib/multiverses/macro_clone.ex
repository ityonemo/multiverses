defmodule Multiverses.Clone do
  @moduledoc """
  allows a module to directly clone all of the public functions of a
  given module, except as macros.

  thus multiverse equivalents replicate the functionality of the parent
  module.  Consider dropping a cloned module into a `test/support`
  directory so that it can exist as compile-time for test, but not
  for dev or prod.

  ## Usage

  In the following example, `FooModule` has all of its functions ported
  into the current module as `defdelegate/2`.  The functions `FooModule.foo/3`
  and `FooModule.foo/4` are not, but rather should be ported using `defclone/2`

  ```elixir
  use Multiverses.Clone, with: FooModule, except: [
    foo: 3,
    foo: 4
  ]
  ```
  """

  defmacro __using__(opts) do
    unless Keyword.has_key?(opts, :module) and
           Keyword.has_key?(opts, :except) do
      raise CompileError,
        file: __CALLER__.file,
        line: __CALLER__.line,
        description: "Clone must have :module and :except options"
    end

    module = Macro.expand(opts[:module], __CALLER__)
    except = Macro.expand(opts[:except], __CALLER__)

    Module.put_attribute(__CALLER__.module, :parent_module, module)

    :functions
    |> module.__info__
    |> Enum.reject(&(&1 in except))
    |> Enum.map(&_mfa_to_defdelegate(module, &1))
  end

  @spec _mfa_to_defdelegate(module, {atom, arity}) :: Macro.t
  @doc false
  ## NB This function should be considered "private" and is only public
  ## so that it can be testable.
  def _mfa_to_defdelegate(module, {function, arity}) do
    {:defdelegate, [context: Elixir, import: Kernel],
      [{function, [], arity_to_params(arity)}, [to: module]]}
  end

  defp arity_to_params(arity, unquoted \\ false)
  defp arity_to_params(0, _), do: Elixir
  defp arity_to_params(arity, unquoted) do
    wrap = if unquoted, do: &unquoted/1, else: &(&1)
    for idx <- 1..arity do
      param = String.to_atom("p#{idx}")
      wrap.({param, [], Elixir})
    end
  end

  defp unquoted(param), do: {:unquote, [], [param]}
end
