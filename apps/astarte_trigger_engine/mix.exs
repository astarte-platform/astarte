#
# This file is part of Astarte.
#
# Copyright 2017-2020 Ispirata Srl
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
      version: "0.11.4",
      elixir: "~> 1.8",
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
      dialyzer_cache_directory: dialyzer_cache_directory(Mix.env()),
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
      {:astarte_core, github: "astarte-platform/astarte_core", branch: "release-0.11"},
      {:astarte_data_access,
       github: "astarte-platform/astarte_data_access", branch: "release-0.11"}
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
      {:amqp, "== 1.2.1"},
      {:bbmustache, "== 1.8.0"},
      {:certifi, "== 2.5.2", override: true},
      {:conform, "== 2.5.2"},
      {:cyanide, "== 1.0.0"},
      {:httpoison, "== 1.5.1"},
      {:jason, "== 1.1.2"},
      {:distillery, "== 1.5.5", runtime: false},
      {:excoveralls, "== 0.11.1", only: :test},
      {:plug_cowboy, "== 2.1.0"},
      {:prometheus_process_collector, "== 1.4.5"},
      {:prometheus_plugs, "== 1.1.5"},
      {:prometheus_ex, "== 3.0.5"},
      {:mox, "== 0.5.1", only: :test},
      {:pretty_log, "== 0.1.0"},
      {:telemetry, "== 0.4.1"},
      {:xandra, "== 0.13.1"},
      {:dialyzex,
       github: "Comcast/dialyzex",
       ref: "cdc7cf71fe6df0ce4cf59e3f497579697a05c989",
       only: [:dev, :ci]}
    ]
  end
end
