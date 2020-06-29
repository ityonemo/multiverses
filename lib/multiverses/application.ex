defmodule Multiverses.Application do
  @moduledoc """
  This module is intended to be a drop-in replacement for `Application`.

  When you drop this module in, fnctions relating to runtime environment
  variables have been substituted with equivalent macros that respect the
  Multiverse pattern.

  ## Warning

  This module is as dangerous as it is useful, so **please make sure you know
  what you're doing before you use this**.  Always test your system in a
  staging system that has `:use_multiverses` unset, before deploying code
  that uses this module.

  The functions calls which take options (:timeout, :persist) are not
  supported, since it's likely that if you're using these options, you're
  probably not in a situation where you need multiverses.

  For the same reason, `:get_all_env` and `:put_all_env` are not supported
  and will default the Elixir standard.
  """

  use Multiverses.MacroClone,
    module: Application,
    except: [delete_env: 2,
             fetch_env!: 2, fetch_env: 2,
             get_env: 2, get_env: 3,
             put_env: 3]

  defmacro universe(key) do
    quote do
      require Multiverses
      {Multiverses.self(), unquote(key)}
    end
  end

  defclone delete_env(app, key) do
    import Multiverses.Application, only: [universe: 1]
    case Elixir.Application.fetch_env(app, universe(key)) do
      {:ok, _} ->
        Elixir.Application.delete_env(app, universe(key))
      :error ->
        Elixir.Application.put_env(app, universe(key), :"$tombstone")
    end
  end

  defclone fetch_env(app, key) do
    import Multiverses.Application, only: [universe: 1]
    case Elixir.Application.fetch_env(app, universe(key)) do
      {:ok, :"$tombstone"} -> :error
      result = {:ok, _} -> result
      :error ->
        Elixir.Application.fetch_env(app, key)
    end
  end

  defclone fetch_env!(app, key) do
    import Multiverses.Application, only: [universe: 1]
    case Elixir.Application.fetch_env(app, universe(key)) do
      {:ok, env} -> env
      :error ->
        Elixir.Application.fetch_env!(app, key)
    end
  end

  defclone get_env(app, key) do
    Multiverses.Application.get_env(app, key, nil)
  end

  defclone get_env(app, key, default) do
    case Multiverses.Application.fetch_env(app, key) do
      {:ok, env} -> env
      :error ->
        # fall back to the global value.
        Elixir.Application.get_env(app, key, default)
    end
  end

  defclone put_env(app, key, value) do
    import Multiverses.Application, only: [universe: 1]
    Elixir.Application.put_env(app, universe(key), value)
  end

end
