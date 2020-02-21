#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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
      version: "1.0.0-dev",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.10",
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

  def application do
    [
      extra_applications: [:lager, :logger],
      mod: {Astarte.Housekeeping, []}
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
      {:astarte_data_access, in_umbrella: true},
      {:astarte_rpc, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, github: "astarte-platform/astarte_core", branch: "master"},
      {:astarte_data_access, github: "astarte-platform/astarte_data_access", branch: "master"},
      {:astarte_rpc, github: "astarte-platform/astarte_rpc", branch: "master"}
    ]
  end

  defp deps do
    [
      {:xandra, "~> 0.13"},
      {:conform, "== 2.5.2"},
      {:distillery, "~> 1.5", runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:dialyzex, github: "Comcast/dialyzex", only: [:dev, :ci]},
      {:plug_cowboy, "~> 2.1"},
      {:prometheus_process_collector, "~> 1.4"},
      {:prometheus_plugs, "~> 1.1"},
      {:prometheus_ex, "~> 3.0"},
      {:pretty_log, "~> 0.1"}
    ]
  end
end
