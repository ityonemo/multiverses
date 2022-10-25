defmodule MultiversesTest.BasicGenServer do
  @moduledoc false

  @gen_server Multiverses.GenServer
  use GenServer

  def start_link(options) do
    @gen_server.start_link(__MODULE__, :state, options)
  end

  @impl true
  def init(:state), do: {:ok, :state}

  def get_token(srv, what), do: @gen_server.call(srv, {:token, what})

  @impl true
  def handle_call({:token, what}, _from, state) do
    {:reply, Multiverses.token(what), state}
  end
end
