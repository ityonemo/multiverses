defmodule Multiverses do
  @moduledoc """
  Elixir introduces into the world of CS, the "multiverse testing" pattern.
  This is a pattern where tests are run concurrently and each test sees a
  shard of global state.

  ## Examples:

  - `Mox`: each tests has access to the global module mock, sharded by the
    pid of the running test.
  - `Ecto`: each test has access to a "database sandbox", which is a
    checked out transaction on the global database that acts as its own
    database shard.
  - `Hound`,`Wallaby`: each test generates an ID that is passed outside of
    the BEAM that is reintercepted on ingress to the BEAM; this ID is
    then used to reconnect to the parent test pid.

  This library implements Multiverses-aware versions of several constructs
  in the Elixir Standard Library which aren't natively Multiversable.
  Additional plugins will be provided for other systems, such as Phoenix.PubSub

  ## Usage

  In your module where you'll be using at least one multiverse module, use the
  following header:

  ```elixir
  use Multiverses, with: Registry, only: :test
  ```

  this aliases `Multiverses.Registry` to `Registry` and activates the
  `Multiverses.Registry` macros across this module.  As an escape hatch, if you
  need to use the underlying module, you may use the macro alias `Elixir.Registry`

  ### Options

  - `:with` the names of multiverse modules you'd like to use.  May be a single module
    or a list of modules.  Is identical to `require <module>; alias <module>`.
  - `:only` activate the multiverse system only in certain Mix environments.  May be
    a single atom or a list of atoms.
  """

  @opaque link :: [pid]

  defmacro __using__(options) do
    activate = Mix.env() in List.wrap(Keyword.get(options, :only, [Mix.env()]))
    [quote do
      @use_multiverses unquote(activate)
      require Multiverses
    end | Keyword.get(options, :with, [])
    |> List.wrap
    |> Enum.map(fn module_ast ->
      module = Module.concat(Multiverses, Macro.expand(module_ast, __CALLER__))

      quote do
        require unquote(module)
        alias unquote(module)
      end
    end)]
  end

  @doc """
  generates a "link" to current universe.  If you pass the result of "link"
  to `port/1`, then it will bring the ported process into the universe of
  the process that called `link/0`
  """
  defmacro link do
    quote do
      [self() | Process.get(:"$callers", [])]
    end
  end

  @doc """
  causes the current process to adopt the universe referred to by the result
  of a `link/0` call.
  """
  defmacro port(callers) do
    quote do
      Process.put(:"$callers", unquote(callers))
    end
  end

  @doc """
  identifies the universe of the current process.
  """
  defmacro self do
    quote do
      :"$callers" |> Process.get([self()]) |> List.last
    end
  end

end
