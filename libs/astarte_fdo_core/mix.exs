defmodule Astarte.FDO.Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_fdo_core,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [plt_add_apps: [:ex_unit], plt_core_path: dialyzer_cache_directory(Mix.env())],
      deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp astarte_required_modules("true") do
    [
      {:astarte_core, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, github: "astarte-platform/astarte_core"}
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer_cache_directory(:ci) do
    "dialyzer_cache"
  end

  defp dialyzer_cache_directory(_) do
    nil
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.10"},
      {:typed_ecto_schema, "~> 0.4"},
      {:cbor, "~> 1.0"},
      {:cose, github: "secomind/cose-elixir"},
      {:excoveralls, "~> 0.15", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test, :ci], runtime: false},
      {:mimic, "~> 1.11", only: :test},
      {:skogsra, "~> 2.2"},
      {:typedstruct, "~> 0.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
