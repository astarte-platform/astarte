#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.RPC.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_rpc,
      version: "1.3.0-rc.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [plt_add_apps: [:ex_unit, :astarte_events]],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Astarte.RPC.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:astarte_core,
       github: "astarte-platform/astarte_core", branch: "release-1.3", override: true},
      {:astarte_data_access, path: "../astarte_data_access"},
      {:astarte_events, path: "../astarte_events", runtime: false},
      {:astarte_generators, github: "astarte-platform/astarte_generators", only: [:dev, :test]},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:libcluster, "~> 3.3"},
      {:mimic, "~> 1.11", only: [:test, :dev]},
      {:phoenix_pubsub, "~> 2.0"},
      {:skogsra, "~> 2.0"},
      {:typedstruct, "~> 0.5"},
      {:excoveralls, "~> 0.15", only: :test}
    ]
  end
end
