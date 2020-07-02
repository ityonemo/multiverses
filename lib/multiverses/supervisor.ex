defmodule Multiverses.Supervisor do

  @moduledoc """
  This module is intended to be a drop-in replacement for `Supervisor`.

  It launches the supervisor and the supervisor *unconditionally*
  inherits the `:"$caller"` of whoever launched it.

  ## Usage

  This module should only be used when you are creating a custom
  [module-based Supervisor](https://hexdocs.pm/elixir/master/Supervisor.html#module-module-based-supervisors).

  ### Example:

  ```elixir
  defmodule MyApp.CustomSupervisor do
    use Multiverses, with: Supervisor
    use Supervisor

    def start_link(arg, opts) do
      Supervisor.start_link(__MODULE__, arg, opts)
    end

    @impl true
    def init(_arg) do
      children = [
        ... supervised children
      ]
      Supervisor.init(children, strategy: :one_for_one)
    end
  end
  ```
  """

  use Multiverses.MacroClone,
    module: Supervisor,
    except: [start_link: 2, start_link: 3]

  defmacro __using__(opts) do
    quote do
      @behaviour Supervisor

      # inject a startup function equivalent to GenServer's do_start.
      # note that, here we're going to inject a custom "init_it" function
      # into this selfsame module (instead of using the :gen_server) init_it
      # which will catch the callers parameters that we're sending over.

      @doc false
      def do_start(link, module, arg, options) do
        portal = [callers: Multiverses.link()]
        case Keyword.pop(options, :name) do
          {nil, opts} ->
            init_arg = {self(), module, arg}
            :gen.start(__MODULE__, link, :supervisor, init_arg, opts ++ portal)

          {atom, opts} when is_atom(atom) ->
            raise ArgumentError, "atom name not supported with multiverses"

          {{:global, _term} = tuple, opts} ->
            raise ArgumentError, "global not supported with multiverses"

          {{:via, via_module, _term} = tuple, opts} when is_atom(via_module) ->
            raise ArgumentError, "via not supported with multiverses"

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
      def init_it(starter, self_param, name, module, args, options!) do
        Multiverses.port(options![:callers])
        options! = Keyword.delete(options!, :callers)
        # dirty little secret: Supervisors are just GenServers under the hood.
        :gen_server.init_it(starter, self_param, name, module, args, options!)
      end

      # implements child_spec in the same way that GenServer does.
      def child_spec(init_arg) do
        default = %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]},
          type: :supervisor
        }

        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      defoverridable child_spec: 1
    end
  end

  @doc """
  starts a Supervisor, linked to the calling function.
  """
  defclone start_link(module, init_state, opts \\ []) do
    __MODULE__.do_start(:link, module, init_state, opts)
  end

end
