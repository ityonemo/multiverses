defmodule Multiverses.Application do
  @moduledoc """
  This module is intended to be a drop-in replacement for `Application`.

  When you drop this module in, functions relating to runtime environment
  variables have been substituted with equivalent macros that respect the
  Multiverse pattern.

  ## Warning

  This module is as dangerous as it is useful, so **please make sure you know
  what you're doing before you use this**.  Always test your system in a
  staging system that has `:use_multiverses` unset, before deploying code
  that uses this module.

  The functions calls which take options (`:timeout`, `:persist`) are not
  supported, since it's likely that if you're using these options, you're
  probably not in a situation where you need multiverses.

  For the same reason, `:get_all_env` and `:put_all_env` are not supported
  and will default the Elixir standard.

  ## How it works

  This module works by substituting the `app` atom with the
  `{multiverse, app}` tuple.  If that tuple isn't found, it falls back
  on the `app` atom for its ETS table lookup.
  """

  use Multiverses.Clone,
    module: Application,
    except: [delete_env: 2,
             fetch_env!: 2, fetch_env: 2,
             get_env: 2, get_env: 3,
             put_env: 3]

  # we're abusing the application key format, which works because ETS tables
  # are what back the application environment variables, and the system
  # tolerates "other terms", even though that's now how they are typespecced
  # out.
  @dialyzer {:nowarn_function,
    delete_env: 2,
    fetch_env: 2,
    fetch_env!: 2,
    get_env: 2,
    get_env: 3,
    put_env: 3}

  defp universe(key) do
    require Multiverses
    {Multiverses.self(), key}
  end

  @doc "See `Application.delete_env/2`."
  def delete_env(app, key) do
    case Application.fetch_env(app, universe(key)) do
      {:ok, _} ->
        Application.delete_env(app, universe(key))
      :error ->
        Application.put_env(app, universe(key), :"$tombstone")
    end
  end

  @doc "See `Application.fetch_env/2`."
  def fetch_env(app, key) do
    case Application.fetch_env(app, universe(key)) do
      {:ok, :"$tombstone"} -> :error
      result = {:ok, _} -> result
      :error ->
        Application.fetch_env(app, key)
    end
  end

  @doc "See `Application.fetch_env!/2`."
  def fetch_env!(app, key) do
    case Application.fetch_env(app, universe(key)) do
      {:ok, env} -> env
      :error ->
        Application.fetch_env!(app, key)
    end
  end

  @doc "See `Application.get_env/2`."
  def get_env(app, key) do
    Multiverses.Application.get_env(app, key, nil)
  end

  @doc "See `Application.get_env/3`."
  def get_env(app, key, default) do
    case Multiverses.Application.fetch_env(app, key) do
      {:ok, env} -> env
      :error ->
        # fall back to the global value.
        Application.get_env(app, key, default)
    end
  end

  @doc "See `Application.put_env/3`."
  def put_env(app, key, value) do
    Application.put_env(app, universe(key), value)
  end

end
