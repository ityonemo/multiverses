# Multiverses

## Multiverses for Elixir.

Don't let Mox, Ecto, Hound and Wallaby have ALL the fun!

Wubba dubba lub lub!

## Testing

you can activate multiple copies of all the tests by passing the
`REPLICATION` system environment variable:

```
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
    {:multiverses, "~> 0.1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/multiverses](https://hexdocs.pm/multiverses).

