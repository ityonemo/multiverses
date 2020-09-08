Application.put_env(:multiverses, :global, :value)
Application.put_env(:multiverses, :use_multiverses, true)

__DIR__
|> Path.join("_support")
|> File.ls!()
|> Enum.map(fn file ->
  Path.join([__DIR__, "_support", file])
end)
|> Enum.each(&Code.compile_file/1)

ExUnit.start()
