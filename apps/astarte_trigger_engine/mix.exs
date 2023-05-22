#
# This file is part of Astarte.
#
# Copyright 2017-2021 Ispirata Srl
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

defmodule Astarte.TriggerEngine.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_trigger_engine,
      elixir: "~> 1.14",
      version: "1.1.0-alpha.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
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
      {:astarte_data_access, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, github: "astarte-platform/astarte_core", branch: "release-1.1"},
      {:astarte_data_access,
       github: "astarte-platform/astarte_data_access", branch: "release-1.1"}
    ]
  end

  def application do
    [
      extra_applications: [:lager, :logger],
      mod: {Astarte.TriggerEngine.Application, []}
    ]
  end

  defp deps do
    [
      {:amqp, "~> 2.1"},
      {:bbmustache, "~> 1.9"},
      {:castore, "~> 0.1.0"},
      {:cyanide, github: "ispirata/cyanide"},
      {:httpoison, "~> 1.6"},
      {:jason, "~> 1.2"},
      {:excoveralls, "~> 0.15", only: :test},
      # hex.pm package and esl/ex_rabbit_pool do not support amqp version 2.1.
      # This fork is supporting amqp ~> 2.0 and also ~> 3.0.
      {:ex_rabbit_pool, github: "leductam/ex_rabbit_pool"},
      {:plug_cowboy, "~> 2.1"},
      {:telemetry_metrics_prometheus_core, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:mox, "~> 0.5", only: :test},
      {:pretty_log, "~> 0.1"},
      {:telemetry, "~> 0.4"},
      {:xandra, "~> 0.13"},
      {:skogsra, "~> 2.2"},
      {:observer_cli, "~> 1.5"},
      {:dialyxir, "~> 1.0", only: [:dev, :ci], runtime: false}
    ]
  end
end
