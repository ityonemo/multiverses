# Multiverses

## Multiverses for Elixir.

Don't let Mox, Ecto, Hound and Wallaby have ALL the fun!

Wubba dubba lub lub!

## Usage

add a line into the configuration (typically `test.exs`):

```elixir
config :my_app, use_multiverses: true
```

If you'd like to drop in multiverse sharding for a given module,
You should structure your module as follows:

```elixir
defmodule MyModule do
  use Multiverses, with: Registry

  def my_function(...) do
    # uses Multiverses.Registry when enabled.
    Registry.unegister(...)
  end
end
```

Some modules which change their implementation, may instead activate
themselves via the `use` directive.  For example:

```elixir
defmodule MyServer do

  use Multiverses.GenServer

  def start_link(_) do
    # uses Multiverses.GenServer in
    GenServer.
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
    {:multiverses, "~> 0.7.0", only: :test}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/multiverses](https://hexdocs.pm/multiverses).

