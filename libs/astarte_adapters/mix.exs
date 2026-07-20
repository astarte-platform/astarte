defmodule Astarte.Adapters.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_adapters,
      version: "1.5.0-dev",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      description: description(),
      package: package(),
      dialyzer: [plt_add_apps: [:ex_unit]],
      deps: deps(),
      source_url: "https://github.com/astarte-platform/astarte/libs/astarte_adapters",
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
      {:typed_ecto_schema, "~> 0.4", only: :test},
      {:excoveralls, "~> 0.15", only: :test},
      {:stream_data, "~> 1.3", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
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
