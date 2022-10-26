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
      start_link: 2,
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
      # TODO: refactor this monstrosity
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

        adjust = fn
          ^match_var, _self ->
            {:element, 2, match_var}

          list, self when is_list(list) ->
            Enum.map(list, &self.(&1, self))

          tuple, self when is_tuple(tuple) ->
            tuple
            |> Tuple.to_list()
            |> self.(self)
            |> List.to_tuple()

          map, self when is_map(map) ->
            map
            |> Enum.map(fn
              {key, value} ->
                {self.(key, self), self.(value, self)}
            end)
            |> Enum.into(%{})

          any, _self ->
            any
        end

        new_filters =
          adjust.(filters, adjust) ++
            [{:==, {:element, 1, match_var}, {:const, universe}}]

        new_result = adjust.(result, adjust)

        {new_match, new_filters, new_result}
      end)

    Registry.select(registry, new_spec)
  end

  def unregister(registry, key) do
    Registry.unregister(registry, {id(), key})
  end

  def update_value(registry, key, callback) do
    Registry.update_value(registry, {id(), key}, callback)
  end

  def whereis_name({registry, key}), do: Registry.whereis_name({registry, {id(), key}})
  def whereis_name({registry, key, _value}), do: Registry.whereis_name({registry, {id(), key}})
end
