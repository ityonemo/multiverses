defmodule MultiversesTest.BasicGenServer do
  use Multiverses.GenServer, only: :test

  def start_link(_) do
    GenServer.start_link(__MODULE__, :state)
  end

  @impl true
  def init(:state), do: {:ok, :state}

  def get_universe(srv), do: GenServer.call(srv, :universe)

  @impl true
  def handle_call(:universe, _from, state) do
    {:reply, Multiverses.self(), state}
  end
end
