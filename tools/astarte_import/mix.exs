defmodule Astarte.Import.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_import,
      version: "0.11.3",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :xmerl]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:xandra, "== 0.13.1"},
      {:logfmt, "== 3.3.1"},
      {:astarte_core, github: "astarte-platform/astarte_core", tag: "v0.11.3"},
      {:astarte_data_access, github: "astarte-platform/astarte_data_access", tag: "v0.11.3"},
      {:distillery, "== 2.0.14"}
    ]
  end
end
