defmodule Astarte.Import.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_import,
      version: "1.2.0-dev",
      elixir: "~> 1.11",
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
      {:xandra, "~> 0.13"},
      {:logfmt, "~> 3.3"},
      {:astarte_core, github: "astarte-platform/astarte_core"},
      {:astarte_data_access, github: "astarte-platform/astarte_data_access"},
      {:distillery, "~> 2.0"}
    ]
  end
end
