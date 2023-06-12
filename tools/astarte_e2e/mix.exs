#
# This file is part of Astarte.
#
# Copyright 2020-2021 Ispirata Srl
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

defmodule AstarteE2E.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_e2e,
      version: "1.2.0-dev",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      dialyzer_cache_directory: dialyzer_cache_directory(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {AstarteE2E.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp dialyzer_cache_directory(:ci) do
    "dialyzer_cache"
  end

  defp dialyzer_cache_directory(_) do
    nil
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:astarte_device, github: "astarte-platform/astarte-device-sdk-elixir"},
      {:phoenix_gen_socket_client,
       github: "J0/phoenix_gen_socket_client", ref: "5e8dee43a0fe877f747cf707baf0d45f713b223a"},
      {:websocket_client, "~> 1.2"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:skogsra, "~> 2.3"},
      {:telemetry, "~> 0.4"},
      {:telemetry_metrics_prometheus_core, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:logfmt, "~> 3.3"},
      {:pretty_log, "~> 0.1"},
      {:observer_cli, "~> 1.5"},
      {:bamboo, "~> 1.6"},
      {:bamboo_config_adapter, "~> 1.0"},
      {:hukai, "~> 0.3"},
      {:dialyzex, github: "Comcast/dialyzex", only: [:dev, :ci]}
    ]
  end
end
