defmodule Astarte.FDO.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_fdo,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      dialyzer: [plt_core_path: dialyzer_cache_directory(Mix.env())],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

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
      {:dialyxir, "~> 1.0", only: [:dev, :ci], runtime: false},
      {:typedstruct, "~> 0.5"}
    ]
  end
end
