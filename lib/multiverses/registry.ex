defmodule Multiverses.Registry do
  @moduledoc """
  This module is intended to be a drop-in replacement for `Registry`, but
  not all functionality is implemented.

  If universes are active, keys in the Registry will be `{universe, key}`
  instead of the normal `key`.  A convenience `via/2` macro has been
  provided, which will perform this substitution correctly.

  Unimplemented functionality:
  - `count_match/3,4`
  - `match/3,4`
  - `unregister_match/3,4`
  """

  @doc false
  def register_name(_, _)

  @doc false
  def send(_, _)

  @doc false
  def unregister_name(_)

  use Multiverses.Clone,
    module: Registry,
    except: [
      count: 1,
      dispatch: 3,
      dispatch: 4,
      keys: 2,
      lookup: 2,
      register: 3,
      unregister: 2,
      update_value: 3,
      select: 2,
      whereis_name: 1,
      # these two functions are deprecated.
      start_link: 3,
      # these two functions are deprecated.
      start_link: 2
    ]

  require Multiverses

  defp id, do: Multiverses.id(Registry)

  def count(registry) do
    selection = [
      {
        {:"$1", :_, :_},
        [{:==, {:element, 1, :"$1"}, {:const, id()}}],
        [:"$1"]
      }
    ]

    registry
    |> Registry.select(selection)
    |> Enum.count()
  end

  def dispatch(registry, key, fun, opts \\ []) do
    Registry.dispatch(registry, {id(), key}, fun, opts)
  end

  def keys(registry, pid) do
    id = id()

    registry
    |> Registry.keys(pid)
    |> Enum.map(fn {^id, key} -> key end)

    # NB: there shouldn't be any pids that don't match this universe.
  end

  def lookup(registry, key) do
    Registry.lookup(registry, {id(), key})
  end

  @doc """
  Registers the calling process with the Registry.  Works as `Registry.register/3` does.
  """
  def register(registry, key, value) do
    Registry.register(registry, {id(), key}, value)
  end

  def select(registry, spec) do
    universe = id()

    new_spec =
      Enum.map(spec, fn {match, filters, result} ->
        {new_match, match_var} =
          case match do
            {:_, a, b} -> {{:"$4", a, b}, :"$4"}
            {a, b, c} -> {{a, b, c}, a}
          end

        # this adjustment function has to takes existing filters and results
        # and intrusively changes them to select on the second part of the
        # element when the match var matches the first position.  This needs
        # to be a arity-2 function that is passed itself, to allow using
        # recursivity in a lambda with a y-combinator technique.
        # NB: this needs to be a lambda so that Multiverses can be compile-time
        # only.

        new_filters =
          adjust(filters, match_var) ++
            [{:==, {:element, 1, match_var}, {:const, universe}}]

        new_result = adjust(result, match_var)

        {new_match, new_filters, new_result}
      end)

    Registry.select(registry, new_spec)
  end

  defp adjust(match_var, match_var) do
    {:element, 2, match_var}
  end

  defp adjust(list, match_var) when is_list(list) do
    Enum.map(list, &adjust(&1, match_var))
  end

  defp adjust(tuple, match_var) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> adjust(match_var)
    |> List.to_tuple()
  end

  defp adjust(map, match_var) when is_map(map) do
    Map.new(map, fn {k, v} -> {adjust(k, match_var), adjust(v, match_var)} end)
  end

  defp adjust(any, _), do: any

  def unregister(registry, key) do
    Registry.unregister(registry, {id(), key})
  end

  def update_value(registry, key, callback) do
    Registry.update_value(registry, {id(), key}, callback)
  end

  def whereis_name({registry, key}), do: Registry.whereis_name({registry, {id(), key}})
  def whereis_name({registry, key, _value}), do: Registry.whereis_name({registry, {id(), key}})
end
