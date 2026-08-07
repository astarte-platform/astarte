defmodule Astarte.Config.MixProject do
  use Mix.Project

  @external_resource Path.join(__DIR__, "../../VERSION")
  @version File.read!(Path.join(__DIR__, "../../VERSION")) |> String.trim()

  def project do
    [
      app: :astarte_config,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
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
      {:decimal, "~> 3.0", override: true},
      {:xandra, github: "whatyouhide/xandra", override: true},
      {:hackney, github: "benoitc/hackney", override: true},
      {:exandra, github: "vinniefranco/exandra", override: true},
      {:cyanide, github: "noaccOS/cyanide", branch: "push-wuxvrvwqsrxv", override: true},
      {:astarte_core, github: "astarte-platform/astarte_core", override: true},
      {:typedstruct, github: "saleyn/typedstruct", override: true},
      {:pretty_log, "~> 0.1"},
      {:skogsra, "~> 2.2"},
      {:castore, "~> 1.0"},
      {:astarte_generators, in_umbrella: true, only: [:dev, :test]},
      {:excoveralls, "~> 0.15", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:httpoison, "~> 3.0"},
      {:mix_audit, "~> 2.1", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
