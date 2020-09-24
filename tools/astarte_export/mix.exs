defmodule AstarteExport.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_export,
      version: "0.11.3",
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
      {:xandra, "== 0.13.1"},
      {:astarte_core, github: "astarte-platform/astarte_core", tag: "v0.11.3"},
      {:astarte_data_access, github: "astarte-platform/astarte_data_access", tag: "v0.11.3"},
      {:distillery, "== 2.0.14"},
      {:pretty_log, "== 0.1.0"},
      {:xml_stream_writer, "== 0.1.0"},
      {:excoveralls, "== 0.11.1", only: :test},
      {:dialyzex, github: "Comcast/dialyzex", ref: "cdc7cf71fe6df0ce4cf59e3f497579697a05c989", only: [:dev, :ci]}
    ]
  end
end
