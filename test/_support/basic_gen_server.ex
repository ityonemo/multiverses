defmodule MultiversesTest.BasicGenServer do
  @moduledoc false

  use Multiverses, with: GenServer
  use GenServer

  def start_link(options) do
    GenServer.start_link(__MODULE__, :state, options)
  end

  @impl true
  def init(:state), do: {:ok, :state}

  def get_universe(srv), do: GenServer.call(srv, :universe)

  @impl true
  def handle_call(:universe, _from, state) do
    {:reply, Multiverses.self(), state}
  end
end
