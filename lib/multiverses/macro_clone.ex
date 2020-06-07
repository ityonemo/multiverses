defmodule Multiverses.MacroClone do
  @moduledoc """
  allows a module to directly clone all of the public functions of a
  given module, except as macros.

  this allows multiverse equivalents to replicate the functionality of
  the parent module, except have the equivalents generated at compiletime,
  allowing multiverse apps to exist as [runtime: false] apps.
  """

  defmacro __using__(opts) do
    unless Keyword.has_key?(opts, :module) and
           Keyword.has_key?(opts, :except) do
      raise CompileError,
        file: __CALLER__.file,
        line: __CALLER__.line,
        description: "MacroClone must have :module and :except options"
    end

    module = Macro.expand(opts[:module], __CALLER__)
    except = Macro.expand(opts[:except], __CALLER__)

    :functions
    |> module.__info__
    |> Enum.reject(&(&1 in except))
    |> Enum.map(&mfa_to_macro(module, &1))
  end

  @spec mfa_to_macro(module, {atom, arity}) :: Macro.t
  @doc false
  ## NB This function should be considered "private" and is only public
  ## so that it can be testable.
  def mfa_to_macro(module, {function, arity}) do
    {:defmacro, [context: Elixir, import: Kernel],
    [
      {function, [context: Elixir], arity_to_params(arity)},
      [do: {:quote, [context: Elixir], [[do: {:__block__, [], [
        mfa_to_call({module, function, arity})
      ]}]]}]
    ]}
  end

  @spec mfa_to_call(mfa) :: Macro.t
  @doc false
  ## NB This function should be considered "private" and is only public
  ## so that it can be testable.
  def mfa_to_call({module, function, arity}) do
    module_alias = module
    |> Module.split
    |> Enum.map(&String.to_atom/1)

    {{:., [], [{:__aliases__, [alias: false], module_alias}, function]}, [],
    arity_to_params(arity, true)}
  end

  defp arity_to_params(arity, unquoted \\ false)
  defp arity_to_params(0, _), do: []
  defp arity_to_params(arity, unquoted) do
    wrap = if unquoted, do: &unquoted/1, else: &(&1)
    for idx <- 1..arity do
      param = String.to_atom("p#{idx}")
      wrap.({param, [], Elixir})
    end
  end

  defp unquoted(param), do: {:unquote, [], [param]}
end
