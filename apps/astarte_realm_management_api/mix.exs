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

defmodule Astarte.RealmManagement.API.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_realm_management_api,
      version: "0.10.2",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.6",
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
      deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Astarte.RealmManagement.API.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp astarte_required_modules("true") do
    [
      {:astarte_core, in_umbrella: true},
      {:astarte_rpc, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, github: "astarte-platform/astarte_core", branch: "release-0.10"},
      {:astarte_rpc, github: "astarte-platform/astarte_rpc", branch: "release-0.10"}
    ]
  end

  defp deps do
    [
      {:phoenix, "== 1.3.2"},
      {:phoenix_pubsub, "== 1.0.2"},
      {:gettext, "~> 0.11"},
      {:cors_plug, "== 1.5.2"},
      {:cowboy, "== 1.1.2"},
      {:ranch, "== 1.4.0", override: true},
      {:conform, "== 2.5.2"},
      {:ecto, "== 2.2.10"},
      {:guardian, github: "ispirata/guardian"},
      {:distillery, "== 1.5.2", runtime: false},
      {:excoveralls, "== 0.9.1", only: :test}
    ]
  end
end
