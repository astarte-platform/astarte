defmodule Astarte.MixProject do
  use Mix.Project

  @external_resource Path.join(__DIR__, "VERSION")
  @version File.read!(Path.join(__DIR__, "VERSION")) |> String.trim()

  def project do
    [
      apps_path: "apps",
      version: @version,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      releases: releases()
    ]
  end

  # Dialyzer runs at the umbrella root (CI dialyzer job). No paths:/plt_add_apps:
  # needed: the umbrella children and ex_unit are in dialyzer_files/deps PLT by
  # default; only astarte_generators needs the opaque-term check disabled.
  defp dialyzer do
    [flags: [:no_opaque]]
  end

  # Umbrella root releases: build each service/tool with `mix release <app>`
  # from the root. Root-level dep overrides (see deps/0) are only visible when
  # converging from here, so `cd apps/<app> && mix release` would not resolve.
  defp releases do
    # Services that ship a rel/overlays (healthcheck script); the umbrella root
    # release would not pick it up otherwise.
    services_with_overlays = [
      :astarte_appengine_api,
      :astarte_data_updater_plant,
      :astarte_housekeeping,
      :astarte_pairing,
      :astarte_realm_management,
      :astarte_trigger_engine
    ]

    # All releases share the root rel/env.sh.eex (sets the Erlang node name and
    # distribution) and, when defined, the per-app rel/overlays.
    for app <- [
          # Services
          :astarte_appengine_api,
          :astarte_data_updater_plant,
          :astarte_housekeeping,
          :astarte_pairing,
          :astarte_realm_management,
          :astarte_trigger_engine,
          :astarte_vmq_plugin,
          # Tools
          :astarte_device_fleet_simulator,
          :astarte_e2e,
          :astarte_export,
          :astarte_import
        ] do
      release_opts = [applications: [{app, :permanent}]]

      release_opts =
        if app in services_with_overlays do
          [{:overlays, ["apps/#{app}/rel/overlays"]} | release_opts]
        else
          release_opts
        end

      {app, release_opts}
    end
  end

  defp deps do
    [
      {:astarte_core, github: "astarte-platform/astarte_core", override: true},
      {:cyanide, github: "noaccOS/cyanide", branch: "push-wuxvrvwqsrxv", override: true},
      {:decimal, "~> 3.0", override: true},
      {:exandra, github: "vinniefranco/exandra", override: true},
      {:hackney, github: "benoitc/hackney", override: true},
      {:httpoison, "~> 3.0", override: true},
      # req comes via mneme -> igniter ("~> 0.5", all vulnerable to
      # GHSA-655f-mp8p-96gv); bump to the first patched line, which requires
      # mime ~> 2.0.6 (bamboo 1.x pins mime ~> 1.4; it only uses MIME.from_path/1,
      # still present in mime 2.x).
      {:mime, "~> 2.0.6", override: true},
      {:req, "~> 0.6.3", override: true},
      {:typedstruct, github: "saleyn/typedstruct", override: true},
      {:xandra, github: "whatyouhide/xandra", override: true}
    ]
  end
end
