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

defmodule Astarte.TriggerEngine.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_trigger_engine,
      elixir: "~> 1.15",
      version: "1.3.0",
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
      {:astarte_generators, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core,
       github: "astarte-platform/astarte_core", branch: "release-1.3", override: true},
      {:astarte_data_access,
       github: "astarte-platform/astarte_data_access", branch: "release-1.3"},
      {:astarte_generators, github: "astarte-platform/astarte_generators", only: [:dev, :test]}
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Astarte.TriggerEngine.Application, []}
    ]
  end

  defp deps do
    [
      {:amqp, "~> 3.3"},
      {:bbmustache, "~> 1.9"},
      {:castore, "~> 1.0.0"},
      {:cyanide, "~> 2.0"},
      {:httpoison, "~> 1.6"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.1"},
      {:telemetry_metrics_prometheus_core, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:typed_ecto_schema, "~> 0.4"},
      {:typedstruct, "~> 0.5"},
      {:ecto, "~> 3.12"},
      {:pretty_log, "~> 0.1"},
      {:telemetry, "~> 0.4"},
      {:exandra, "~> 0.13"},
      {:skogsra, "~> 2.2"},
      {:observer_cli, "~> 1.5"},
      # hex.pm package and esl/ex_rabbit_pool do not support amqp version 2.1.
      # This fork is supporting amqp ~> 2.0 and also ~> 3.0.
      {:ex_rabbit_pool, github: "leductam/ex_rabbit_pool"},
      {:dialyxir, "~> 1.0", only: [:dev, :ci], runtime: false},
      {:excoveralls, "~> 0.15", only: :test},
      {:mox, "~> 0.5", only: :test},
      {:mimic, "~> 1.11", only: :test},
      # Workaround for Elixir 1.15 / ssl_verify_fun issue
      # See also: https://github.com/deadtrickster/ssl_verify_fun.erl/pull/27
      {:ssl_verify_fun, "~> 1.1.0", manager: :rebar3, override: true}
    ]
  end
end
