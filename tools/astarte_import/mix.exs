defmodule Astarte.Import.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_import,
      version: "1.3.0-rc.1",
      elixir: "~> 1.15",
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
      {:xandra, "~> 0.19.4"},
      {:exandra, "~>0.16.0"},
      {:ecto, "~>3.13"},
      {:logfmt, "~> 3.3"},
      {:astarte_core, github: "astarte-platform/astarte_core", tag: "v1.3.0-rc.1"},
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
