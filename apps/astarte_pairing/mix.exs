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

defmodule Astarte.Pairing.Mixfile do
  use Mix.Project

  @external_resource Path.join(__DIR__, "../../VERSION")
  @version File.read!(Path.join(__DIR__, "../../VERSION")) |> String.trim()

  def project do
    [
      app: :astarte_pairing,
      elixir: "~> 1.20",
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      deps: deps(),
      description: "Astarte Pairing API"
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Astarte.Pairing.Application, []},
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
      {:xandra, github: "whatyouhide/xandra", override: true},
      {:cyanide, github: "noaccOS/cyanide", branch: "push-wuxvrvwqsrxv", override: true},
      {:castore, "~> 1.0.0"},
      {:phoenix, "~> 1.7"},
      {:gettext, "~> 0.24"},
      {:bandit, "~> 1.11"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_view, "~> 2.0"},
      {:jason, "~> 1.2"},
      {:cbor, "~> 1.0"},
      {:cose, github: "secomind/cose-elixir"},
      {:guardian, "~> 2.4"},
      {:remote_ip, "~> 1.0"},
      {:excoveralls, "~> 0.15", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:pretty_log, "~> 0.1"},
      {:plug_logger_with_meta, "~> 0.1"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:skogsra, "~> 2.2"},
      {:cors_plug, "~> 2.0"},
      {:telemetry, "~> 1.3", override: true},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:observer_cli, "~> 1.5"},
      {:cfxxl, github: "secomind/cfxxl", branch: "main"},
      {:astarte_core, github: "astarte-platform/astarte_core", override: true},
      {:typedstruct, github: "saleyn/typedstruct", override: true},
      {:astarte_realm_management, in_umbrella: true, only: :test, runtime: false},
      {:astarte_data_access, in_umbrella: true},
      {:astarte_generators, in_umbrella: true, only: [:dev, :test]},
      {:astarte_secrets, in_umbrella: true},
      {:bcrypt_elixir, "~> 2.2"},
      {:ecto, "~> 3.13", override: true},
      {:exandra, github: "vinniefranco/exandra", override: true},
      {:decimal, "~> 3.0", override: true},
      {:mimic, "~> 2.3", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:con_cache, "~> 1.1"},
      {:astarte_events, in_umbrella: true},
      {:astarte_fdo, in_umbrella: true},
      {:astarte_fdo_core, in_umbrella: true},
      {:astarte_rpc, in_umbrella: true},
      {:open_api_spex, "~> 3.22"},
      {:ymlr, "~> 5.1"},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:httpoison, "~> 3.0"},
      {:hackney, github: "benoitc/hackney", override: true}
    ]
  end
end
