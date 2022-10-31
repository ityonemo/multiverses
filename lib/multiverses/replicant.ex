if Application.compile_env(:multiverses, :with_replicant, false) do
  defmodule MultiversesTest.Replicant do
    @moduledoc """
    allows you to replicate test module multiple times, forcing them to
    be run concurrently.  This helps prove that the system can be run
    in parallel without issue.

    you should set the replication level with the REPLICATION environment
    variable, for example:

    ```shell
    REPLICATION=10 mix test
    ```
    """

    @doc """
    use in place of `defmodule/2` for any test you'd like replicated.
    """
    defmacro defmoduler(module, do: do_block) do
      module = Macro.expand(module, __CALLER__)

      replication =
        "REPLICATION"
        |> System.get_env("1")
        |> String.to_integer()

      for index <- 1..replication do
        module_instance = Module.concat(module, "Instance#{index}Test")

        quote do
          defmodule unquote(module_instance), do: unquote(do_block)
        end
      end
    end
  end
end
