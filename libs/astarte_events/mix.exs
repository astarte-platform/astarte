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
defmodule Astarte.Events.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_events,
      elixir: "~> 1.15",
      version: "0.0.2",
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
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Astarte.Events.Application, []}
    ]
  end

  # Compile order is relevant: we make sure support files are available when testing
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer_cache_directory(:ci), do: "dialyzer_cache"
  defp dialyzer_cache_directory(_), do: nil

  defp deps do
    [
      {:amqp, "~> 3.3"},
      {:castore, "~> 1.0.0"},
      {:excoveralls, "~> 0.15", only: :test},
      {:ex_rabbit_pool, github: "leductam/ex_rabbit_pool"},
      {:skogsra, "~> 2.2"},
      {:mox, "~> 1.0", only: :test},
      {:mimic, "~> 1.11", only: [:dev, :test]},
      {:dialyxir, "~> 1.0", only: [:dev, :ci], runtime: false},
      # Workaround for Elixir 1.15 / ssl_verify_fun issue
      # See also: https://github.com/deadtrickster/ssl_verify_fun.erl/pull/27
      {:ssl_verify_fun, "~> 1.1.0", manager: :rebar3, override: true},
      {:astarte_data_access,
       github: "astarte-platform/astarte_data_access", branch: "release-1.3"},
      {:astarte_core, github: "astarte-platform/astarte_core", branch: "release-1.3"},
      {:elixir_uuid, "~> 1.2"}
    ]
  end
end
