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
    [
      plt_add_apps: [:ex_unit, :astarte_realm_management]
    ]
  end

  defp releases do
    for app <- [
          :astarte_appengine_api,
          :astarte_data_updater_plant,
          :astarte_housekeeping,
          :astarte_pairing,
          :astarte_realm_management,
          :astarte_trigger_engine,
          :astarte_vmq_plugin
        ] do
      release_opts = [applications: [{app, :permanent}], overlays: ["apps/#{app}/rel/overlays"]]

      {app, release_opts}
    end
  end

  defp deps do
    [
      # We need the hardcoded version from 343c6435a7ef06dd2662e950d33cb957f81bf68d
      {:typedstruct, github: "saleyn/typedstruct", override: true},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end
end
