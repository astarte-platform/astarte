#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_data_updater_plant,
      elixir: "~> 1.15",
      version: "1.3.0-rc.0",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [plt_add_apps: [:astarte_housekeeping, :astarte_realm_management, :ex_unit]],
      deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Astarte.DataUpdaterPlant.Application, []}
    ]
  end

  # Compile order is relevant: we make sure support files are available when testing
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp astarte_required_modules("true") do
    [
      {:astarte_core, in_umbrella: true},
      {:astarte_generators, in_umbrella: true, only: [:dev, :test]}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, github: "astarte-platform/astarte_core", branch: "release-1.3"},
      {:astarte_generators, github: "astarte-platform/astarte_generators", only: [:dev, :test]},
      {:astarte_realm_management,
       path: "../astarte_realm_management", only: :test, runtime: false},
      {:astarte_housekeeping,
       path: "../astarte_housekeeping", only: :test, env: :dev, runtime: false},
      {:astarte_events, path: astarte_lib("astarte_events")}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
      {:amqp, "~> 3.3"},
      {:castore, "~> 1.0.0"},
      {:cyanide, "~> 2.0"},
      {:excoveralls, "~> 0.15", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:mimic, "~> 1.11", only: [:dev, :test]},
      {:exandra, "~> 0.13"},
      # hex.pm package and esl/ex_rabbit_pool do not support amqp version 2.1.
      # This fork is supporting amqp ~> 2.0 and also ~> 3.0.
      {:ex_rabbit_pool, github: "leductam/ex_rabbit_pool"},
      {:libcluster, "~> 3.3"},
      {:horde, "~> 0.9"},
      {:pretty_log, "~> 0.1"},
      {:plug_cowboy, "~> 2.1"},
      {:typed_ecto_schema, "~> 0.4"},
      {:xandra, "~> 0.13"},
      {:astarte_data_access, path: astarte_lib("astarte_data_access"), override: true},
      {:astarte_rpc, path: astarte_lib("astarte_rpc")},
      {:skogsra, "~> 2.2"},
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:observer_cli, "~> 1.5"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      # Workaround for Elixir 1.15 / ssl_verify_fun issue
      # See also: https://github.com/deadtrickster/ssl_verify_fun.erl/pull/27
      {:ssl_verify_fun, "~> 1.1.0", manager: :rebar3, override: true},
      # TODO: needed to run test because we cannot start the housekeeping application as is
      {:httpoison, "~> 2.2", only: [:dev, :test]},
      {:uuid, "~> 2.0", hex: :uuid_erl},
      {:typedstruct, "~> 0.5"}
    ]
  end

  defp astarte_lib(library_name) do
    base_directory = System.get_env("ASTARTE_LIBRARIES_PATH", "../../libs")
    Path.join(base_directory, library_name)
  end
end
