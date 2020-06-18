defmodule Multiverses.MacroClone do
  @moduledoc """
  allows a module to directly clone all of the public functions of a
  given module, except as macros.

  thus multiverse equivalents replicate the functionality of the parent
  module, except with the equivalents substituted at compile time,
  allowing multiverse apps to exist as `[runtime: false]` apps.

  ## Usage

  In the following example, `FooModule` has all of its functions ported
  into the current module, except as macros.  The functions `FooModule.foo/3`
  and `FooModule.foo/4` are not, but rather should be ported using `defclone/2`

  ```elixir
  use Multiverses.MacroClone, with: FooModule, except: [
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
        description: "MacroClone must have :module and :except options"
    end

    module = Macro.expand(opts[:module], __CALLER__)
    except = Macro.expand(opts[:except], __CALLER__)

    Module.put_attribute(__CALLER__.module, :parent_module, module)

    :functions
    |> module.__info__
    |> Enum.reject(&(&1 in except))
    |> Enum.map(&mfa_to_macro(module, &1))
    |> Kernel.++([quote do
      import Multiverses.MacroClone, only: [defclone: 2]
    end])
  end

  @spec defclone(Macro.t, Macro.t) :: Macro.t
  @doc """
  clones the target function from the parent module (as defined in the `use` statement)
  as a macro, unless `use Multiverses` has been activated.

  In the case that `use Multiverses` has been activated, the macro takes the value of the
  contents inside the `defclone` block.
  """
  defmacro defclone(header, do: block) do
    {fun, _, params} = header

    # the cloned macro needs to keep the default values.
    macro_params = Enum.map(
      params, fn
        {:\\, _, [{var, _, _}, default]} ->
          {:\\, [], [{var, [], Elixir}, default]}
        {var, _, nil} ->
          {var, [], Elixir}
      end)

    # inner functon values don't keep the default values.
    args = Enum.map(macro_params, fn
      {:\\, _, [any, _]} -> any
      any -> any
    end)

    parent = __CALLER__.module
    |> Module.get_attribute(:parent_module)
    |> Module.split
    |> Enum.map(&String.to_atom/1)

    {:defmacro, [context: Elixir, import: Kernel],
    [
      {fun, [context: Elixir], macro_params},
      [do: clone_body(parent, fun, args, block)]
    ]}
  end

  defp clone_body(module, fun, args, block) do
    quote do
      this_app = Mix.Project.get
      |> apply(:project, [])
      |> Keyword.get(:app)

      use_multiverses? = __CALLER__.module
      |> Module.get_attribute(:multiverse_otp_app, this_app)
      |> Application.get_env(:use_multiverses, this_app == :multiverses)

      if use_multiverses? do
        unquote(block_call(args, block))
      else
        unquote(naked_call(module, fun, args))
      end
    end
  end

  defp block_call(args, block) do
    {:quote, [context: Elixir],
      [[bind_quoted: bind_args(args)], [do: block]]}
  end

  defp naked_call(module, fun, args) do
    call = {
      {:., [], [{:__aliases__, [alias: false], module}, fun]},
      [],
      Enum.map(args, &to_unquoted/1)}

    {:quote, [context: Elixir], [[do: call]]}
  end

  defp bind_args(args) do
    Enum.map(args, fn {var, _, _} ->
      {var, {var, [], Elixir}}
    end)
  end

  defp to_unquoted(var), do: {:unquote, [], [var]}

  @spec mfa_to_macro(module, {atom, arity}) :: Macro.t
  @doc false
  ## NB This function should be considered "private" and is only public
  ## so that it can be testable.
  def mfa_to_macro(module, {function, arity}) do
    [mfa_to_doc({module, function, arity}),
    {:defmacro, [context: Elixir, import: Kernel],
    [
      {function, [context: Elixir], arity_to_params(arity)},
      [do: {:quote, [context: Elixir], [[do: {:__block__, [], [
        mfa_to_call({module, function, arity})
      ]}]]}]
    ]}]
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

  defp mfa_to_doc({module, function, arity}) do
    m = module |> Module.split |> Enum.join(".")
    docstr = "cloned from `#{m}.#{function}/#{arity}`"
    quote do
      @doc unquote(docstr)
    end
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
