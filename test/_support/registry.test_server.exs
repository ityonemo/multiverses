defmodule MultiversesTest.Registry.TestServer do
  @moduledoc false

  @registry Multiverses.Registry

  use GenServer

  def start_link(reg, name) do
    GenServer.start_link(__MODULE__, {self(), reg, name})
  end

  def init({parent, reg, name}) do
    Multiverses.allow(Registry, parent, self())
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
