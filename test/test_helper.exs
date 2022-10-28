Application.put_env(:multiverses, :global, :value)

Task.start_link(fn ->
  System.cmd("epmd", [])
end)

Process.sleep(100)
{:ok, _} = :net_kernel.start([:primary, :shortnames])
:peer.start(%{name: :peer})
[_] = Node.list()

ExUnit.start()
