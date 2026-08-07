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

  @external_resource Path.join(__DIR__, "../../VERSION")
  @version File.read!(Path.join(__DIR__, "../../VERSION")) |> String.trim()

  def project do
    [
      app: :astarte_data_updater_plant,
      elixir: "~> 1.20",
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Astarte.DataUpdaterPlant.Application, []}
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

  # Compile order is relevant: we make sure support files are available when testing
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:xandra, github: "whatyouhide/xandra", override: true},
      {:jason, "~> 1.2"},
      {:amqp, "~> 4.1"},
      {:castore, "~> 1.0.0"},
      {:cbor, "~> 1.0"},
      {:con_cache, "~> 1.0"},
      {:cose, github: "secomind/cose-elixir"},
      {:cyanide, github: "noaccOS/cyanide", branch: "push-wuxvrvwqsrxv", override: true},
      {:excoveralls, "~> 0.15", only: :test},
      {:mississippi, github: "secomind/mississippi"},
      {:mox, "~> 1.0", only: :test},
      {:mimic, "~> 2.3", only: :test},
      {:exandra, github: "vinniefranco/exandra", override: true},
      {:decimal, "~> 3.0", override: true},
      {:libcluster, "~> 3.3"},
      # https://github.com/elixir-horde/horde/pull/291
      {:horde, github: "noaccOS/horde", branch: "push-ozyqtonylvpv"},
      {:pretty_log, "~> 0.1"},
      {:bandit, "~> 1.11"},
      {:typed_ecto_schema, "~> 0.4"},
      {:astarte_core, github: "astarte-platform/astarte_core", override: true},
      {:astarte_realm_management, in_umbrella: true, only: :test, runtime: false},
      {:astarte_events, in_umbrella: true},
      {:astarte_secrets, in_umbrella: true},
      {:astarte_generators, in_umbrella: true, only: [:dev, :test]},
      {:astarte_data_access, in_umbrella: true},
      {:astarte_rpc, in_umbrella: true},
      {:skogsra, "~> 2.2"},
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:observer_cli, "~> 1.8"},
      {:recon, "2.5.6", override: true},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:uuid, "~> 2.0", hex: :uuid_erl},
      {:typedstruct, github: "saleyn/typedstruct", override: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:hkdf, "~> 0.3.0"},
      {:httpoison, "~> 3.0", override: true},
      {:hackney, github: "benoitc/hackney", override: true}
    ]
  end
end
