defmodule Astarte.Adapters.MixProject do
  use Mix.Project

  @external_resource Path.join(__DIR__, "../../VERSION")
  @version File.read!(Path.join(__DIR__, "../../VERSION")) |> String.trim()

  def project do
    [
      app: :astarte_adapters,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      description: description(),
      package: package(),
      deps: deps(),
      source_url: "https://github.com/astarte-platform/astarte/apps/astarte_adapters",
      homepage_url: "https://astarte-platform.org/"
    ]
  end

  def cli do
    [
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp description do
    """
    Astarte Adapters library.
    """
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
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
      {:astarte_data_access, in_umbrella: true, runtime: false},
      {:astarte_generators, in_umbrella: true, only: [:dev, :test]},
      {:ecto, "~> 3.13.0", override: true},
      {:ecto_sql, "~> 3.13.0", override: true},
      {:excoveralls, "~> 0.15", only: :test},
      {:stream_data, "~> 1.3", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:mix_audit, "~> 2.1", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      maintainers: ["Gabriele Ghio"],
      licenses: ["Apache-2.0"],
      links: %{
        "Astarte" => "https://astarte-platform.org",
        "GitHub" => "https://github.com/astarte-platform/astarte"
      }
    ]
  end
end
