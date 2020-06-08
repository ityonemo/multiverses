defmodule Multiverses.Registry do
  @moduledoc """
  This module is intended to be a drop-in replacement for `Registry`, though
  currently not all functionality is implemented.

  Unimplemented functionality:
  - `count_match/3,4`
  - `match/3,4`
  - `unregister_match/3,4`
  """

  use Multiverses.MacroClone,
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
      select: 2
    ]

  defclone count(registry) do
    registry
    |> Registry.select([
      {
        {:"$1", :_, :_},
        [{:==, {:element, 1, :"$1"}, {:const, Multiverses.self()}}],
        [:"$1"]
      }
    ])
    |> Enum.count()
  end

  defclone dispatch(registry, key, fun, opts \\ []) do
    Registry.dispatch(registry, {Multiverses.self(), key}, fun, opts)
  end

  defclone keys(registry, pid) do
    universe = Multiverses.self()

    registry
    |> Registry.keys(pid)
    |> Enum.map(fn {^universe, key} -> key end)

    # NB: there shouldn't be any pids that don't match this universe.
  end

  defclone lookup(registry, key) do
    Registry.lookup(registry, {Multiverses.self(), key})
  end

  @doc """
  Registers the calling process with the Registry.  Works as `Registry.register/3` does.
  """
  defclone register(registry, key, value) do
    Registry.register(registry, {Multiverses.self(), key}, value)
  end

  defclone select(registry, spec) do
    universe = Multiverses.self()
    new_spec = Enum.map(spec, fn {match, filters, result} ->
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

  defclone unregister(registry, key) do
    Registry.unregister(registry, {Multiverses.self(), key})
  end

  defclone update_value(registry, key, callback) do
    Registry.update_value(registry, {Multiverses.self(), key}, callback)
  end

  @doc """
  retrives a process stored in the registry by its key.  If multiverses
  are activated, then this shards the registry by universe, and the caller
  will only be able to see processes in its universe.
  """
  defmacro get(registry, key) do
    if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do
        case Registry.select(
               unquote(registry),
               [
                 {{:"$1", :"$2", :_},
                  [{:==, :"$1", {:const, {Multiverses.self(), unquote(key)}}}], [:"$2"]}
               ]
             ) do
          [pid] -> pid
          [] -> nil
        end
      end
    else
      quote do
        case Registry.select(
               unquote(registry),
               [{{:"$1", :"$2", :_}, [{:==, :"$1", {:const, unquote(key)}}], [:"$2"]}]
             ) do
          [pid] -> pid
          [] -> nil
        end
      end
    end
  end

  @doc """
  retrives all processes stored in the registry by their keys.  If multiverses
  are activated, then this shards the registry by universe, and the caller
  will only be able to see processes in its universe.
  """
  defmacro all(registry) do
    if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do
        Registry.select(
          unquote(registry),
          [
            {{:"$1", :"$2", :_},
             [
               {:andalso, {:is_tuple, :"$1"},
                {:==, {:element, 1, :"$1"}, {:const, Multiverses.self()}}}
             ], [:"$2"]}
          ]
        )
      end
    else
      quote do
        Registry.select(unquote(registry), [{{:"$1", :"$2", :_}, [], [:"$2"]}])
      end
    end
  end
end
