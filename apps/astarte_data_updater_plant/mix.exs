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

defmodule Astarte.DataUpdaterPlant.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_data_updater_plant,
      version: "0.11.1",
      elixir: "~> 1.8",
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

  def application do
    [
      extra_applications: [:lager, :logger],
      mod: {Astarte.DataUpdaterPlant.Application, []}
    ]
  end

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
      {:astarte_core, github: "astarte-platform/astarte_core", tag: "v0.11.1"},
      {:astarte_data_access, github: "astarte-platform/astarte_data_access", tag: "v0.11.1"},
      {:astarte_rpc, github: "astarte-platform/astarte_rpc", tag: "v0.11.1"}
    ]
  end

  defp deps do
    [
      {:amqp, "== 1.2.1"},
      {:cyanide, "== 1.0.0"},
      {:conform, "== 2.5.2"},
      {:distillery, "== 1.5.5", runtime: false},
      {:excoveralls, "== 0.11.1", only: :test},
      {:pretty_log, "== 0.1.0"},
      {:plug_cowboy, "== 2.1.0"},
      {:prometheus_process_collector, "== 1.4.5"},
      {:prometheus_plugs, "== 1.1.5"},
      {:xandra, "== 0.13.1"},
      {:prometheus_ex, "== 3.0.5"},
      {:telemetry, "== 0.4.1"},
      {:dialyzex,
       github: "Comcast/dialyzex",
       ref: "cdc7cf71fe6df0ce4cf59e3f497579697a05c989",
       only: [:dev, :ci]}
    ]
  end
end
