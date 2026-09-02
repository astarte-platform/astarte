defmodule Astarte.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      # x-release-please-start-version
      version: "1.5.0-dev",
      # x-release-please-end
      description: "Open Source IoT platform focused on data management and processing",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: dialyzer(),
      releases: releases()
    ]
  end

  def cli do
    [
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp dialyzer do
    []
  end

  defp releases do
    []
  end

  defp deps do
    [
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end
end
