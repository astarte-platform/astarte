defmodule Astarte.Import.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_import,
      # x-release-please-start-version
      version: "1.5.0-dev",
      # x-release-please-end
      elixir: "~> 1.20",
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
      {:exandra, github: "vinniefranco/exandra"},
      {:ecto, "~>3.13"},
      {:logfmt, "~> 3.3"},
      {:astarte_core, path: astarte_lib("astarte_core"), override: true},
      {:astarte_data_access, path: astarte_lib("astarte_data_access")},
      {:jason, "~> 1.4"},
      {:distillery, "~> 2.0"}
    ]
  end

  defp astarte_lib(library_name) do
    base_directory = System.get_env("ASTARTE_LIBRARIES_PATH", "../../libs")
    Path.join(base_directory, library_name)
  end
end
