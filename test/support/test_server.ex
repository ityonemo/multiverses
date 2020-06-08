defmodule MultiversesTest.Registry.TestServer do
  use Multiverses, with: Registry

  use GenServer

  def start_link(reg, name) do
    link = Multiverses.link()
    GenServer.start_link(__MODULE__, {reg, name, link})
  end

  def init({reg, name, link}) do
    Multiverses.port(link)
    Registry.register(reg, name, nil)
    {:ok, nil}
  end
end
