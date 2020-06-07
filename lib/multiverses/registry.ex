defmodule Multiverses.Registry do
  @moduledoc """
  This module is intended to be a drop-in replacement for `Registry`, though
  currently not all functionality is implemented.
  """

  use Multiverses.MacroClone, module: Registry, except: [
    register: 3
  ]

  @doc """
  Registers the calling process with the Registry.  Works as `Registry.register/3` does.

  If multiverses have not been activated, then `nil` is placed as the registry value.
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

  @doc """
  retrives a process stored in the registry by its key.  If multiverses
  are activated, then this shards the registry by universe, and the caller
  will only be able to see processes in its universe.
  """
  defmacro get(registry, key) do
    if Module.get_attribute(__CALLER__.module, :use_multiverses) do
      quote do
        require Multiverses
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
