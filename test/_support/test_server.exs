defmodule MultiversesTest.Registry.TestServer do
  @moduledoc false

  @registr Multiverses.Registry

  use GenServer

  def start_link(reg, name) do
    link = Multiverses.link()
    GenServer.start_link(__MODULE__, {reg, name, link})
  end

  def init({reg, name, link}) do
    Multiverses.port(link)
    @registry.register(reg, name, nil)
    {:ok, name}
  end

  def unregister(reg, srv), do: GenServer.call(srv, {:unregister, reg})

  def update(reg, srv, val), do: GenServer.call(srv, {:update, reg, val})

  def handle_call({:unregister, reg}, _, name) do
    @registry.unregister(reg, name)
    {:reply, :ok, name}
  end
  def handle_call({:update, reg, val}, _, name) do
    @registry.update_value(reg, name, val)
    {:reply, :ok, name}
  end
end
