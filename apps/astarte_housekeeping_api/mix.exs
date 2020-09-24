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

defmodule Astarte.Housekeeping.API.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_housekeeping_api,
      version: "0.11.3",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
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

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Astarte.Housekeeping.API.Application, []},
      extra_applications: [:lager, :logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
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
      {:astarte_rpc, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_rpc, github: "astarte-platform/astarte_rpc", tag: "v0.11.3"}
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:conform, "== 2.5.2"},
      {:jason, "== 1.1.2"},
      {:phoenix, "== 1.4.9"},
      {:phoenix_ecto, "== 4.0.0"},
      {:gettext, "== 0.16.1"},
      {:cors_plug, "== 1.5.2"},
      {:plug_cowboy, "== 2.1.0"},
      {:guardian, "== 1.2.1"},
      {:distillery, "== 1.5.5", runtime: false},
      {:excoveralls, "== 0.11.1", only: :test},
      {:prometheus_process_collector, "== 1.4.5"},
      {:prometheus_phoenix, "== 1.3.0"},
      {:prometheus_plugs, "== 1.1.5"},
      {:pretty_log, "== 0.1.0"},
      {:dialyzex,
       github: "Comcast/dialyzex",
       ref: "cdc7cf71fe6df0ce4cf59e3f497579697a05c989",
       only: [:dev, :ci]}
    ]
  end
end
