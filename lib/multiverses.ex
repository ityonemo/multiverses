defmodule Multiverses do
  @moduledoc """
  Elixir introduces into the world of programming, the "multiverse testing"
  pattern.  This is a pattern where integration tests are run concurrently
  and each test sees a shard of global state.

  ## Pre-Existing Examples:

  - `Mox`: each test has access to the global module mock, sharded by the
    pid of the running test.
  - `Ecto`: each test has access to a "database sandbox", which is a
    checked out transaction on the global database that acts as its own
    database shard.
  - `Hound`,`Wallaby`: each test generates an ID that is passed outside of the
    BEAM that is reintercepted on ingress, this ID is then used to connect
    ecto sandboxes to the parent test PID

  This library implements Multiverses-aware versions of several constructs
  in the Elixir Standard Library which aren't natively Multiversable.

  For plugins that are provided for other systems, see the libraries:

  - `:multiverses_finch`  - which extends this to HTTP requests that exit the BEAM.
  - `:multiverses_pubsub` - which extends this to Phoenix.PubSub

  ## Usage

  In `mix.exs`, you should add the following directive:

  ```
  {:multiverses, "~> #{Multiverses.MixProject.version}", runtime: false}
  ```

  In your module where you'll be using at least one multiverse module, use the
  following header:

  ```elixir
  use Multiverses, with: Registry
  ```

  this aliases `Multiverses.Registry` to `Registry`.  As an escape hatch, if
  you must use the underlying module, you may use the macro alias
  `Elixir.Registry`

  If you need more complex choices for when to activate Multiverses (such as system
  environment variables), you should encode those choices directly using logic around
  the `use Multiverses` statement.

  ### Options

  - `:with` the names of multiverse modules you'd like to use.  May be a single module
    or a list of modules.  Is identical to `require Multiverses.<module>; alias Multiverses.<module>`.
  - `:otp_app` the otp_app must have its :use_multiverses application environment
    variable set in order to be used.  Defaults to autodetecting via Mix.
  """

  import Kernel, except: [self: 0]

  @opaque link :: [pid]

  defmacro __using__(options!) do
    otp_app = Keyword.get_lazy(options!, :otp_app, fn ->
      Mix.Project.get
      |> apply(:project, [])
      |> Keyword.get(:app)
    end)

    if in_multiverse?(otp_app) do
      using_multiverses(otp_app, __CALLER__, options!)
    else
      empty_aliases(__CALLER__, options!)
    end
  end

  defp in_multiverse?(otp_app) do
    Application.get_env(otp_app, :use_multiverses, false)
  end

  defp using_multiverses(otp_app, caller, options) do
    Module.register_attribute(
      caller.module,
      :active_modules,
      accumulate: true)

    [quote do
      @multiverse_otp_app unquote(otp_app)
      require Multiverses
     end | options
         |> Keyword.get(:with, [])
         |> List.wrap
         |> Enum.map(fn module_ast ->
           native_module = Macro.expand(module_ast, caller)
           multiverses_module = Module.concat(Multiverses, native_module)

           Module.put_attribute(
             caller.module,
             :active_modules,
             native_module)

           quote do
             alias unquote(multiverses_module)
           end
         end)]
  end

  defp empty_aliases(caller, options) do
    options
    |> Keyword.get(:with, [])
    |> List.wrap
    |> Enum.map(fn module_ast ->
      native_module = Macro.expand(module_ast, caller)
      quote do
        alias unquote(native_module)
      end
    end)
  end

  @spec link() :: link
  @doc """
  generates a "link" to current universe.  If you pass the result of "link"
  to `port/1`, then it will bring the ported process into the universe of
  the process that called `link/0`
  """
  def link do
    [Kernel.self() | Process.get(:"$callers", [])]
  end

  @spec port(link) :: link
  @doc """
  causes the current process to adopt the universe referred to by the result
  of a `link/0` call.
  """
  def port(callers) do
    Process.put(:"$callers", callers)
  end

  @spec self() :: pid
  @doc """
  identifies the universe of the current process.
  """
  def self do
    :"$callers" |> Process.get([Kernel.self()]) |> List.last
  end

  @spec drop() :: link
  @doc """
  purges the caller list.
  """
  def drop do
    Process.delete(:"$callers")
  end

  @spec overrides?(module, module) :: boolean
  @doc """
  this function can identify if a parent module has been overridden
  with its Multiverse equivalent in this module.

  **Important**: the parent_module parameter is interpreted in the
  global aliasing context, and not in the context of the local
  alias.

  useful for making compile-time guarantees, for example in ExUnit
  Case modules.
  """
  defmacro overrides?(module_ast, parent_module_ast) do
    module = Macro.expand(module_ast, __CALLER__)
    # the parent module should be expanded without local aliasing.
    parent_module = Macro.expand(parent_module_ast, __ENV__)
    active_modules = Module.get_attribute(module, :active_modules)
    if active_modules, do: parent_module in active_modules, else: false
  end

  @doc """
  lets you know if the current otp_app has multiverses active.

  Only available at compile time, and only available when compiling
  with Mix.
  """
  defmacro active? do
    quote do
      Application.compile_env(unquote(app()), :use_multiverses, false)
    end
  end

  @doc false
  # used internally to determine which app this this belongs to
  @spec app() :: atom
  def app do
    Mix.Project.get
    |> apply(:project, [])
    |> Keyword.get(:app)
  end

end
