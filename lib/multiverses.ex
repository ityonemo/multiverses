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

  - `:multiverses_req`  - which extends this to HTTP requests that exit the BEAM.
  - `:multiverses_pubsub` - which extends this to Phoenix.PubSub

  ## Usage

  In `mix.exs`, you should add the following directive:

  ```elixir
  {:multiverses, "~> #{Multiverses.MixProject.version()}", runtime: (Mix.env() == :test)}}
  ```

  ### In your code

  For example, if you would like to use the `Multiverses` version of the `Application`
  module, you should add the following lines:

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
    Multiverses.register(Application)
  end
  ```

  2. Your tests should have segregated appliction values!

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

  @type token :: pos_integer()

  @spec register(module) :: :ok
  defdelegate register(module), to: Server

  @spec token(module) :: token
  defdelegate token(module), to: Server

  @spec allow(module, pid | token, term) :: :ok
  defdelegate allow(module, pid, allowed), to: Server
end
