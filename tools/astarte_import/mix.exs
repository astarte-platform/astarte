defmodule Astarte.Import.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_import,
      version: "1.0.0-beta.2",
      elixir: "~> 1.10",
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
      {:astarte_core, "== 1.0.0-beta.1"},
      {:astarte_data_access, "== 1.0.0-beta.1"},
      {:distillery, "~> 2.0"}
    ]
  end
end
