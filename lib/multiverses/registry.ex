defmodule Multiverses.Registry do
  @moduledoc """
  This module is intended to be a drop-in replacement for `Registry`, though
  currently not all functionality is implemented.

  Unimplemented functionality:
  - `count_match/3,4`
  - `match/3,4`
  - `unregister_match/3,4`
  """

  use Multiverses.MacroClone, module: Registry, except: [
    count: 1,
    dispatch: 3,
    dispatch: 4,
    keys: 2,
    lookup: 2,
    register: 3,
    unregister: 2,
    update_value: 3,
    select: 2,
  ]

  defclone count(registry) do
    registry
    |> Registry.select([{
      {:"$1", :_, :_},
      [{:==, {:element, 1, :"$1"}, {:const, Multiverses.self()}}],
      [:"$1"]}])
    |> Enum.count
  end

  #defmacro count(registry) do
  #  if Module.get_attribute(__CALLER__.module, :use_multiverses) do
  #    quote do
  #      unquote(registry)
  #      |> Registry.select([{
  #        {:"$1", :_, :_},
  #        [{:==, {:element, 1, :"$1"}, {:const, Multiverses.self()}}],
  #        [:"$1"]}])
  #      |> Enum.count
  #    end
  #  else
  #    quote do
  #      Registry.count(unquote(registry))
  #    end
  #  end
  #end

  defmacro dispatch(registry, key, fun, opts \\ []) do
    if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do
        Registry.dispatch(unquote(registry), {Multiverses.self(), unquote(key)}, unquote(fun), unquote(opts))
      end
    else
      quote do
        Registry.dispatch(unquote(registry), unquote(key), unquote(fun), unquote(opts))
      end
    end
  end

  defmacro keys(registry, pid) do
    if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do
        universe = Multiverses.self()
        unquote(registry)
        |> Registry.keys(unquote(pid))
        |> Enum.map(fn {^universe, key} -> key end)
        # NB: there shouldn't be any pids that don't match this universe.
      end
    else
      quote do
        Registry.keys(unquote(registry), unquote(pid))
      end
    end
  end

  defmacro lookup(registry, key) do
    if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do
        unquote(registry)
        |> Registry.lookup({Multiverses.self(), unquote(key)})
        |> Enum.map(fn {pid, value} -> {pid, value} end)
        # NB: there shouldn't be any pids that don't match this universe.
      end
    else
      quote do
        Registry.lookup(unquote(registry), unquote(key))
      end
    end
  end

  @doc """
  Registers the calling process with the Registry.  Works as `Registry.register/3` does.
  """
  defmacro register(registry, key, value) do
    modkey = if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do {Multiverses.self(), unquote(key)} end
    else
      key
    end

    quote do
      Registry.register(unquote(registry), unquote(modkey), unquote(value))
    end
  end

  defmacro select(registry, spec) do
    if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do
        universe = Multiverses.self()
        spec = Enum.map(unquote(spec), fn {match, filters, result} ->
          {new_match, match_var} = case match do
            {:_, a, b} -> {{:"$4", a, b}, :"$4"}
            {a, b, c} -> {{a, b, c}, a}
          end

          adjust = fn
            ^match_var, _self ->
              {:element, 2, match_var}
            list, self when is_list(list) ->
              Enum.map(list, &self.(&1, self))
            tuple, self when is_tuple(tuple) ->
              tuple
              |> Tuple.to_list
              |> self.(self)
              |> List.to_tuple
            map, self when is_map(map) ->
              map
              |> Enum.map(fn
                {key, value} ->
                  {self.(key, self), self.(value, self)}
              end)
              |> Enum.into(%{})
            any, _self -> any
          end

          new_filters = adjust.(filters, adjust) ++
            [{:==, {:element, 1, match_var}, {:const, universe}}]


          new_result = adjust.(result, adjust)

          {new_match, new_filters, new_result}
        end)

        Registry.select(unquote(registry), spec)
        # NB: there shouldn't be any pids that don't match this universe.
      end
    else
      quote do
        Registry.select(unquote(registry), unquote(spec))
      end
    end
  end

  defmacro unregister(registry, key) do
    if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do
        Registry.unregister(unquote(registry), {Multiverses.self(), unquote(key)})
      end
    else
      quote do
        Registry.unregister(unquote(registry), unquote(key))
      end
    end
  end

  defmacro update_value(registry, key, callback) do
    if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do
        Registry.update_value(unquote(registry), {Multiverses.self(), unquote(key)}, unquote(callback))
      end
    else
      quote do
        Registry.update_value(unquote(registry), unquote(key), unquote(callback))
      end
    end
  end

  @doc """
  retrives a process stored in the registry by its key.  If multiverses
  are activated, then this shards the registry by universe, and the caller
  will only be able to see processes in its universe.
  """
  defmacro get(registry, key) do
    if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do
        case Registry.select(unquote(registry),
          [{{:"$1", :"$2", :_},
           [{:==, :"$1", {:const, {Multiverses.self(), unquote(key)}}}],
            [:"$2"]}]) do
          [pid] -> pid
          [] -> nil
        end
      end
    else
      quote do
        case Registry.select(unquote(registry),
          [{{:"$1", :"$2", :_},
            [{:==, :"$1", {:const, unquote(key)}}],
            [:"$2"]}]) do
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
        Registry.select(unquote(registry),
          [{{:"$1", :"$2", :_},
            [{:andalso, {:is_tuple, :"$1"}, {:==, {:element, 1, :"$1"}, {:const, Multiverses.self()}}}],
            [:"$2"]}
          ])
      end
    else
      quote do
        Registry.select(unquote(registry), [{{:"$1", :"$2", :_}, [], [:"$2"]}])
      end
    end
  end

end
