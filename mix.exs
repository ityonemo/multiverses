defmodule Multiverses.MixProject do
  use Mix.Project

  def version, do: "0.8.0"

  def project do
    [
      app: :multiverses,
      version: version(),
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env:
        [coveralls: :test,
         "coveralls.detail": :test,
         "coveralls.post": :test,
         "coveralls.html": :test,
         release: :lab],
      package: [
          description: "multiverse support for Elixir Standard Library",
          licenses: ["MIT"],
          files: ~w(lib mix.exs README* LICENSE* VERSIONS*),
          links: %{"GitHub" => "https://github.com/ityonemo/multiverses"}
        ],
      docs: [
        main: "Multiverses",
        extras: ["README.md"],
        source_url: "https://github.com/ityonemo/multiverses"
      ],
      start_permanent: Mix.env() == :prod,
      dialyzer: [ignore_warnings: ".dialyzer_ignore.exs"],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Multiverses.AppSupervisor, []}
    ]
  end

  defp deps do
    [
      {:mox, "~> 0.5", only: :test},
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.11", only: :test, runtime: false},
      {:ex_doc, "~> 0.21.2", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
