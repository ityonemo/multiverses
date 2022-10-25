defmodule MultiversesTest.BasicGenServer do
  @moduledoc false

  @gen_server Multiverses.GenServer
  use GenServer

  def start_link(options) do
    @gen_server.start_link(__MODULE__, :state, options)
  end

  @impl true
  def init(:state), do: {:ok, :state}

  def get_universe(srv), do: @gen_server.call(srv, :universe)

  @impl true
  def handle_call(:universe, _from, state) do
    {:reply, Multiverses.self(), state}
  end
end
