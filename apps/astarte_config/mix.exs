defmodule Astarte.Config.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_config,
      # x-release-please-start-version
      version: "1.5.0-dev",
      # x-release-please-end
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_apps: [:ex_unit]],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:skogsra, "~> 2.2"},
      {:castore, "~> 1.0"},
      {:astarte_generators, path: "../astarte_generators", only: [:dev, :test]},
      {:excoveralls, "~> 0.15", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:httpoison, "~> 3.0"},
      {:mix_audit, "~> 2.1", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
