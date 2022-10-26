# Multiverses

## Multiverses for Elixir.

Don't let Mox, Ecto, Hound and Wallaby have ALL the fun!

Wubba dubba lub lub!

## Usage

add a line into the configuration (typically `test.exs`):

If you'd like to drop in multiverse sharding for registry

```elixir
# config.exs
config :my_app, Registry, Registry
```

```elixir
# test.exs
config :my_app, Registry, Multiverses.Registry
```


```elixir
defmodule MyModule do
  @registry Application.config_env!(:my_app, Registry)

  def my_function(...) do
    # uses Multiverses.Registry when enabled.
    @registry.unregister(...)
  end
end
```

## Testing

you can activate multiple copies of all the tests by passing the
`REPLICATION` system environment variable:

```bash
REPLICATION=10 mix test
```

will copy the test modules 10 times over, so multiple versions of the
same module could possibly run simultaneously.

## Installation

The package can be installed
by adding `multiverses` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:multiverses, "~> 0.8.0", runtime: (Mix.env() == :test)}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/multiverses](https://hexdocs.pm/multiverses).

