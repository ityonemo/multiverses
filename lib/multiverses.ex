defmodule Multiverses do
  @moduledoc """
  Elixir introduces into the world of CS, the "multiverse testing" pattern.
  This is a pattern where tests are run concurrently and each test sees a
  shard of global state.

  ## Examples:

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

  - :multiverses_finch  - which extends this to HTTP requests that exit the BEAM.
  - :multiverses_pubsub - which extends this to Phoenix.PubSub

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

  this aliases `Multiverses.Registry` to `Registry` and activates the
  `Multiverses.Registry` macros across this module.  As an escape hatch, if you
  need to use the underlying module, you may use the macro alias `Elixir.Registry`

  If you need more complex choices for when to activate Multiverses (such as system
  environment variables), you should encode those choices directly using logic around
  the `use Multiverses` statement.

  ### Options

  - `:with` the names of multiverse modules you'd like to use.  May be a single module
    or a list of modules.  Is identical to `require Multiverses.<module>; alias Multiverses.<module>`.
  - `:otp_app` the otp_app must have its :use_multiverses application environment
    variable set in order to be used.
  """

  @opaque link :: [pid]

  defmacro __using__(options) do
    otp_app = Keyword.get_lazy(options, :otp_app, fn ->
      Mix.Project.get
      |> apply(:project, [])
      |> Keyword.get(:app)
    end)

    [quote do
      @multiverse_otp_app unquote(otp_app)
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

  @doc """
  purges the caller list.
  """
  defmacro drop do
    quote do
      Process.delete(:"$callers")
    end
  end

end
