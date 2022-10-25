defmodule Multiverses.GenServer do
  @moduledoc """
  This module is intended to be a drop-in replacement for `use GenServer`.
  Note that this is different from other modules.

  ## Usage

  ```
  defmodule MyModule do

    use Multiverses, with: GenServer
    use GenServer

    def start_link(...) do
      GenServer.start_link(__MODULE__, init, forward_callers: true)
    end

    #
    # standard GenServer code.
    #

  end
  ```

  The Multiverses.GenServer implementation introduces a `:forward_callers`
  option into the GenServer init, setting this to true, allows the
  GenServer to inherit the callers chain of its caller.  This is compatible
  with `Multiverses.DynamicSupervisor`.

  ## Important:

  Typically you won't want GenServers to default to be part of a multiverse
  shard, as they generally represent stateful persistent internal services.
  If the service can exist before and after the test, then you should
  consider NOT using this module.

  ## When you should use this module:

  In some cases, a GenServer will represent a transient connection, or
  a cache for state IRL which is tracked in a specific context.
  """

  use Multiverses.Clone,
    module: GenServer,
    except: [
      start: 2,
      start: 3,
      start_link: 2,
      start_link: 3
    ]

  require Multiverses

  defmacro __using__(opts) do
    gen_server_opts = Macro.escape(opts)

    quote do
      @behaviour GenServer
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

  @doc "See `GenServer.start/3`."
  def start_link(module, init_state, opts \\ []) do
    __MODULE__.do_start(:link, module, init_state, opts)
  end

  @doc "See `GenServer.start_link/3`."
  def start(module, init_state, opts \\ []) do
    __MODULE__.do_start(:nolink, module, init_state, opts)
  end

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
        # trick dialyzer into not complaining about non-local returns.
        case :erlang.phash2(1, 1) do
          0 ->
            raise ArgumentError, """
            expected :name option to be one of the following:
              * nil
              * atom
              * {:global, term}
              * {:via, module, term}
            Got: #{inspect(other)}
            """

          1 ->
            :ignore
        end
    end
  end

  # inject the init_it function that trampolines to gen_server init_it.
  # since this callback is called inside of the spawned gen_server
  # process, we can paint this process with the call chain that
  # lets us identify the correct, sharded universe.

  @doc false
  def init_it(starter, self_param, name, mod, args, options!) do
    if options![:forward_callers] do
      Multiverses.port(options![:callers])
    end

    options! = Keyword.delete(options!, :forward_callers)
    :gen_server.init_it(starter, self_param, name, mod, args, options!)
  end
end
