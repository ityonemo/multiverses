defmodule Multiverses.Application do
  @moduledoc """
  This module is intended to be a drop-in replacement for `Application`.

  When you drop this module in, functions relating to runtime environment
  variables have been substituted with equivalent functions that respect the
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

  """

  use Multiverses.Clone,
    module: Application,
    except: [delete_env: 2, fetch_env!: 2, fetch_env: 2, get_env: 2, get_env: 3, put_env: 3]

  @dialyzer {:nowarn_function,
             delete_env: 2, fetch_env: 2, fetch_env!: 2, get_env: 2, get_env: 3, put_env: 3}

  @spec ensured_get(atom, pos_integer) :: %{optional(pos_integer) => keyword}
  defp ensured_get(app, id) do
    # Ensures the existence of the tree, returns the full multiverse KWL map
    case Application.fetch_env(app, Multiverses) do
      {:ok, map} when is_map_key(map, id) ->
        map
      {:ok, map} ->
        multiverse_map = Map.put(map, id, [])
        Application.put_env(app, Multiverses, multiverse_map)
        multiverse_map
      :error ->
        new_map = %{id => []}
        Application.put_env(app, Multiverses, new_map)
        new_map
    end
  end

  @tombstone :"$multiverse-tombstone"

  @spec fetch_internal(atom, atom) :: {:ok, term} | unquote(@tombstone) | :error
  defp fetch_internal(app, key) do
    id = Multiverses.id(Application)
    env = ensured_get(app, id)[id]
    case Keyword.fetch(env, key) do
      {:ok, @tombstone} -> @tombstone
      {:ok, value} -> {:ok, value}
      :error -> :error
    end
  end


  @doc "See `Application.delete_env/2`."
  def delete_env(app, key) do
    id = Multiverses.id(Application)

    new_envs = app
    |> ensured_get(id)
    |> put_in([id, key], @tombstone)

    Application.put_env(app, Multiverses, new_envs)

    :ok
  end

  @doc "See `Application.fetch_env/2`."
  def fetch_env(app, key) do
    case fetch_internal(app, key) do
      @tombstone -> :error
      :error ->
        Application.fetch_env(app, key)
      value -> value
    end
  end

  @doc "See `Application.fetch_env!/2`."
  def fetch_env!(app, key) do
    case fetch_env(app, key) do
      {:ok, value} ->
        value

      :error ->
        raise ArgumentError,
              "could not fetch application environment #{inspect(key)} for application " <>
                "#{inspect(app)} #{fetch_env_failed_reason(app, key)}"
    end
  end

  defp fetch_env_failed_reason(app, key) do
    vsn = :application.get_key(app, :vsn)

    case vsn do
      {:ok, _} ->
        "because configuration at #{inspect(key)} was not set"

      :undefined ->
        "because the application was not loaded nor configured"
    end
  end

  @doc "See `Application.get_env/2`."
  def get_env(app, key) do
    get_env(app, key, nil)
  end

  @doc "See `Application.get_env/3`."
  def get_env(app, key, default) do
    case fetch_env(app, key) do
      {:ok, env} ->
        env

      :error ->
        # fall back to the global value.
        Application.get_env(app, key, default)
    end
  end

  @doc "See `Application.put_env/3`."
  def put_env(app, key, value) do
    id = Multiverses.id(Application)

    multiverse_kv = app
    |> ensured_get(id)
    |> put_in([id, key], value)

    Application.put_env(app, Multiverses, multiverse_kv)
  end
end
