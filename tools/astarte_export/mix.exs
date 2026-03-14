defmodule AstarteExport.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_export,
      version: "1.3.0-rc.1",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [plt_add_apps: [:ex_unit]],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:astarte_core, github: "astarte-platform/astarte_core", tag: "v1.3.0-rc.1"},
      {:xandra, "~> 0.19.4"},
      {:exandra, "~>0.16.0"},
      {:distillery, "~> 2.1.1"},
      {:pretty_log, "~> 0.9.0"},
      {:xml_stream_writer, "~> 0.1"},
      {:excoveralls, "~> 0.12", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:astarte_data_access, path: astarte_lib("astarte_data_access")}
    ]
  end

  defp astarte_lib(library_name) do
    base_directory = System.get_env("ASTARTE_LIBRARIES_PATH", "../../libs")
    Path.join(base_directory, library_name)
  end
end
