#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Housekeeping.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_housekeeping,
      # x-release-please-start-version
      version: "1.5.0-dev",
      # x-release-please-end
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_apps: [:ex_unit]],
      deps: deps(),
      description: "Astarte Housekeeping API"
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Astarte.Housekeeping.Application, []},
      extra_applications: [:logger, :runtime_tools]
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

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:astarte_core, path: astarte_lib("astarte_core")},
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_view, "~> 2.0"},
      {:gettext, "~> 0.24"},
      {:cors_plug, "~> 2.0"},
      {:bandit, "~> 1.11"},
      {:guardian, "~> 2.4"},
      {:excoveralls, "~> 0.15", only: :test},
      {:exandra, github: "vinniefranco/exandra"},
      {:pretty_log, "~> 0.1"},
      {:skogsra, "~> 2.5"},
      {:observer_cli, "~> 1.5"},
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:mimic, "~> 2.3", only: [:test, :dev]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:astarte_generators, path: astarte_lib("astarte_generators"), only: [:dev, :test]},
      {:astarte_data_access, path: astarte_lib("astarte_data_access")},
      {:astarte_events, path: astarte_lib("astarte_events")},
      {:astarte_secrets, path: astarte_lib("astarte_secrets")},
      {:castore, "~> 1.0.0"},
      {:open_api_spex, "~> 3.22"},
      {:ymlr, "~> 5.1"},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:httpoison, "~> 3.0", override: true},
      {:hackney, github: "benoitc/hackney", override: true},
      {:tzdata, github: "lau/tzdata", override: true}
    ]
  end

  defp astarte_lib(library_name) do
    base_directory = System.get_env("ASTARTE_LIBRARIES_PATH", "../../libs")
    Path.join(base_directory, library_name)
  end
end
