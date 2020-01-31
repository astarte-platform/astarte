defmodule AstarteExport.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_export,
      version: "0.1.0",
      elixir: "~> 1.8",
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
      {:xandra, "~> 0.10"},
      {:astarte_core, github: "astarte-platform/astarte_core"},
      {:astarte_data_access, github: "astarte-platform/astarte_data_access"},
      {:distillery, "~> 2.0.0"},
      {:pretty_log, "~> 0.1.0"},
      {:xml_stream_writer, github: "ispirata/xml_stream_writer"},
      {:excoveralls, "~> 0.11", only: :test},
      {:dialyzex, github: "Comcast/dialyzex", only: [:dev, :ci]}
  ]
  end
end
