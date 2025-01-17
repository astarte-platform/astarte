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
      version: "1.3.0-dev",
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
      dialyzer: [plt_core_path: dialyzer_cache_directory(Mix.env())],
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

  defp dialyzer_cache_directory(:ci) do
    "dialyzer_cache"
  end

  defp dialyzer_cache_directory(_) do
    nil
  end

  defp astarte_required_modules("true") do
    [
      {:astarte_core, in_umbrella: true},
      {:astarte_data_access, in_umbrella: true},
      {:astarte_rpc, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, github: "astarte-platform/astarte_core"},
      {:astarte_data_access, github: "astarte-platform/astarte_data_access"},
      {:astarte_rpc, github: "astarte-platform/astarte_rpc"}
    ]
  end

  defp deps do
    [
      {:amqp, "~> 3.3"},
      {:castore, "~> 1.0.0"},
      {:cyanide, "~> 2.0"},
      {:excoveralls, "~> 0.15", only: :test},
      {:mississippi, github: "secomind/mississippi"},
      {:mox, "~> 1.0", only: :test},
      # hex.pm package and esl/ex_rabbit_pool do not support amqp version 2.1.
      # This fork is supporting amqp ~> 2.0 and also ~> 3.0.
      {:ex_rabbit_pool, github: "simplebet/ex_rabbit_pool", ref: "latest-amqp"},
      {:pretty_log, "~> 0.1"},
      {:plug_cowboy, "~> 2.1"},
      {:telemetry_metrics_prometheus_core, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:xandra, "~> 0.13"},
      {:skogsra, "~> 2.2"},
      {:telemetry, "~> 0.4"},
      {:observer_cli, "~> 1.5"},
      # Fix: re2 1.9.8 to build on arm64
      {:re2, "~> 1.9.8", override: true},
      {:dialyxir, "~> 1.0", only: [:dev, :ci], runtime: false},
      # Workaround for Elixir 1.15 / ssl_verify_fun issue
      # See also: https://github.com/deadtrickster/ssl_verify_fun.erl/pull/27
      {:ssl_verify_fun, "~> 1.1.0", manager: :rebar3, override: true}
    ]
  end
end
