defmodule Multiverses.GenServer do

  @moduledoc """
  This module is intended to be a drop-in replacement for `GenServer`.

  When a GenServer process is created by this module, it inherits the
  callers chain of its parent, in the same way that

  ## Important:

  Typically you won't want GenServers to default to be part of a multiverse
  shard, as they generally represent stateful persistent internal services.
  If the service can exist before and after the test, then you should NOT
  use this module.

  ## When you should use this module:

  In some cases, a GenServer will represent a transient connection, or
  a cache for state IRL which is tracked in a specific context.
  """

  use Multiverses.MacroClone,
    module: GenServer,
    except: [
      start: 2,
      start: 3,
      start_link: 2,
      start_link: 3
    ]

  defmacro __using__(opts) do

    multiverse_opts = Macro.escape(opts) ++ [with: GenServer]
    gen_server_opts = opts |> Keyword.drop([:only]) |> Macro.escape

    quote do
      @behaviour :gen_server

      use Multiverses, unquote(multiverse_opts)

      # inject a startup function equivalent to GenServer's do_start.
      # note that, here we're going to inject a custom "init_it" function
      # into this selfsame module (instead of using the :gen_server) init_it
      # which will catch the callers parameters that we're sending over.

      @doc false
      def do_start(link, module, init_arg, options) do
        portal = [callers: Multiverses.link()]
        case Keyword.pop(options, :name) do
          {nil, opts} ->
            :gen.start(__MODULE__, link, module, init_arg, opts ++ portal)

          {atom, opts} when is_atom(atom) ->
            :gen.start(__MODULE__, link, {:local, atom}, module, init_arg, opts ++ portal)

          {{:global, _term} = tuple, opts} ->
            :gen.start(__MODULE__, link, tuple, module, init_arg, opts ++ portal)

          {{:via, via_module, _term} = tuple, opts} when is_atom(via_module) ->
            :gen.start(__MODULE__, link, tuple, module, init_arg, opts ++ portal)

          {other, _} ->
            raise ArgumentError, """
            expected :name option to be one of the following:
              * nil
              * atom
              * {:global, term}
              * {:via, module, term}
            Got: #{inspect(other)}
            """
        end
      end

      # inject the init_it function that trampolines to gen_server init_it.
      # since this callback is called inside of the spawned gen_server
      # process, we can paint this process with the call chain that
      # lets us identify the correct, sharded universe.

      @doc false
      def init_it(starter, self_param, name, mod, args, options) do
        Multiverses.port(options[:callers])
        :gen_server.init_it(starter, self_param, name, mod, args, options)
      end

      # implements child_spec in the same way that GenServer does.
      def child_spec(init_arg) do
        default = %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]}
        }
        Supervisor.child_spec(default, unquote(gen_server_opts))
      end

      defoverridable child_spec: 1
    end
  end

  @doc """
  starts a GenServer, linked to the calling function.
  """
  defclone start_link(module, init, opts \\ []) do
    __MODULE__.do_start(:link, module, init, opts)
  end

  @doc """
  starts a GenServer, linked to the calling function.
  """
  defclone start(module, init, opts \\ []) do
    __MODULE__.do_start(:nolink, module, init, opts)
  end
end
