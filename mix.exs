defmodule Multiverses.MixProject do
  use Mix.Project

  def version, do: "0.8.1"

  def project do
    [
      app: :multiverses,
      version: version(),
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
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
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Multiverses.AppSupervisor, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/_support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false}
    ]
  end
end
