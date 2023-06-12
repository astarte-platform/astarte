defmodule AstarteExport.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_export,
      version: "1.2.0-dev",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer_cache_directory: dialyzer_cache_directory(Mix.env()),
      deps: deps()
    ]
  end

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

  defp deps do
    [
      {:xandra, "~> 0.13"},
      {:astarte_core, github: "astarte-platform/astarte_core"},
      {:astarte_data_access, github: "astarte-platform/astarte_data_access"},
      {:distillery, "~> 2.0.0"},
      {:pretty_log, "~> 0.1.0"},
      {:xml_stream_writer, "~> 0.1"},
      {:excoveralls, "~> 0.12", only: :test},
      {:dialyzex, github: "Comcast/dialyzex", only: [:dev, :ci]}
    ]
  end
end
