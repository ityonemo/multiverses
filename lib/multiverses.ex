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
  in the Elixir Standard Library that aren't natively Multiversable.

  For plugins that are provided for other systems, see the libraries:

  - `:multiverses_http`  - which extends this to HTTP requests that exit the BEAM.
  - `:multiverses_pubsub` - which extends this to Phoenix.PubSub

  ## Usage

  In `mix.exs`, add the following directive:

  ```elixir
  {:multiverses, "~> #{Multiverses.MixProject.version()}", runtime: (Mix.env() == :test)}}
  ```

  ### In your code

  For example, if you would like to use the `Multiverses` version of the `Application`
  module (`Multiverses.Application`), add the following lines:

  To `config/config.exs`:

  ```elixir
  config :my_app, Application, Application
  ```

  To `config/test.exs`:

  ```elixir
  config :my_app, Application, Multiverses.Application
  ```

  To the module where you would like to use multiverses `Application`:

  ```elixir
  @application Application.compile_env(:my_app, Application)
  ```

  And where you would like to make a multiverses Application call:

  ```elixir
  def some_function do
    value = @application.get_env(:my_app, :some_env_variable)
    # ...
  end
  ```

  ### In your tests

  1. Register the module you'd like to substitute with multiverses.

  ```elixir
  setup do
    Multiverses.shard(Application)
  end
  ```

  2. Your tests have segregated application values!

  ```elixir
  defmodule MyModule do
    @application Multiverses.Application
    def get_and_wait(value) do
      @application.put_env(:my_app, :env, value)
      Process.sleep(1000)
      @application.get_env(:my_app, :env)
    end
  end

  defmodule SomeTest do
    use ExUnit.Case, async: true
    test do
      assert :foo == MyModule.get_and_wait(:foo)
    end
  end

  defmodule SomeOtherTest do
    use ExUnit.Case, async: true
    test do
      assert :bar == MyModule.get_and_wait(:bar)
    end
  end
  ```
  """

  alias Multiverses.Server

  @type id :: pos_integer()

  @spec shard(module | [module]) :: [{module, id}]
  @doc """
  Creates a new shard for a particular domain module and assigns this pid to the
  shard.  You can batch assigning multiple shards as well.
  """
  defdelegate shard(modules), to: Server

  @spec shards :: [{module, id}]
  @spec shards(pid) :: [{module, id}]
  @doc """
  Returns a list of multiverse domain modules and the respective shard-ids associated
  with those domain modules.
  """
  defdelegate shards(pid \\ self()), to: Server

  @spec id(module) :: id
  @spec id(module, options :: keyword) :: id | nil
  @doc """
  Obtains the universe id for the current process.

  This is found by checking process and the entries in the `:$callers` process dictionary
  entry to find if any of them are registered.

  If the current process is not registered, then it raises `Multiverses.UnexpectedCallError`

  ### Options

  - `:strict` (defaults to `true`): if `false`, returns `nil`, instead of crashing.
  """
  def id(module, options \\ []) do
    if id = Process.get({Multiverses, module}) do
      id
    else
      Server.id(module, options)
    end
  end

  @spec allow(module, pid | id, term) :: [{{module, pid}, id}]
  @doc """
  Inspired by `Mox.allow/3`, this function assigns a process or registered name process
  to be put into the shard of a pid or directly into a shard.
  """
  defdelegate allow(module, pid, allowed), to: Server

  @spec allow([{module, id}], term) :: [{{module, pid}, id}]
  @doc """
  Utility version of allow/3 that lets you batch-assign multiple allowances
  """
  defdelegate allow(modules, allowed), to: Server

  ## utility functions
  defdelegate all(module), to: Server

  @spec allow_for(module, id, (() -> result)) :: result when result: term
  @doc """
  Temporarily assigns the running process to the shard, within the scope of
  the provided lambda.  This is done through the process dictionary.  Other
  processes will not be aware that this process has been added to the shard.
  """
  def allow_for(module, id, fun) do
    Process.put({Multiverses, module}, id)
    result = fun.()
    Process.delete({Multiverses, module})
    result
  end

  # errors

  defmodule UnexpectedCallError do
    defexception [:message]
  end
end
