defmodule MultiversesTest.OverridesTest do

  use ExUnit.Case, async: true

  defmodule Success do
    use Multiverses, with: Registry
    @uses_registry Multiverses.overrides?(__MODULE__, Registry)
    def result, do: @uses_registry
  end

  defmodule SuccessAmongMultiple do
    use Multiverses, with: [Registry, GenServer]
    @uses_registry Multiverses.overrides?(__MODULE__, Registry)
    def result, do: @uses_registry
  end

  describe "overrides?/2 correctly detects" do
    test "when a single module has been overridden" do
      assert Success.result()
    end

    test "when multiple modules have been overridden" do
      assert SuccessAmongMultiple.result()
    end
  end

  defmodule TrivialFailure do
    require Multiverses
    @uses_registry Multiverses.overrides?(__MODULE__, Registry)
    def result, do: @uses_registry
  end

  defmodule AlternateFailure do
    use Multiverses, with: GenServer
    @uses_registry Multiverses.overrides?(__MODULE__, Registry)
    def result, do: @uses_registry
  end

  describe "overrides?/2 correctly fails when" do
    test "multiverses is not in use" do
      refute TrivialFailure.result()
    end

    test "when a different module has been multiversed" do
      refute AlternateFailure.result()
    end
  end
end
