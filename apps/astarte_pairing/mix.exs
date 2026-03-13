#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_pairing,
      elixir: "~> 1.15",
      version: "1.4.0-dev",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [plt_add_apps: [:astarte_realm_management, :ex_unit]],
      deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Astarte.Pairing.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp astarte_required_modules("true") do
    [
      {:astarte_core, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, github: "astarte-platform/astarte_core"},
      {:astarte_realm_management,
       path: "../astarte_realm_management", only: :test, runtime: false}
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:castore, "~> 1.0.0"},
      {:astarte_data_access, path: astarte_lib("astarte_data_access"), override: true},
      {:astarte_events, path: astarte_lib("astarte_events")},
      {:astarte_fdo, path: astarte_lib("astarte_fdo"), env: :dev},
      {:astarte_fdo_core, path: astarte_lib("astarte_fdo_core"), env: :dev, override: true},
      {:astarte_generators, path: astarte_lib("astarte_generators"), only: [:dev, :test]},
      {:astarte_rpc, path: astarte_lib("astarte_rpc")},
      {:bcrypt_elixir, "~> 2.2"},
      {:cbor, "~> 1.0"},
      {:cfxxl, github: "ispirata/cfxxl"},
      {:con_cache, "~> 1.1"},
      {:cors_plug, "~> 2.0"},
      {:cose, github: "secomind/cose-elixir"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :ci, :test], runtime: false},
      {:ecto, "~> 3.12"},
      {:exandra, "~> 0.13"},
      {:excoveralls, "~> 0.15", only: :test},
      {:gettext, "~> 0.24"},
      {:guardian, "~> 2.3.2"},
      {:httpoison, "~> 2.2", override: true},
      {:jason, "~> 1.2"},
      {:mimic, "~> 1.11", only: :test},
      {:mox, "~> 0.5", only: :test},
      {:observer_cli, "~> 1.5"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix, "~> 1.7"},
      {:plug_cowboy, "~> 2.2"},
      {:plug_logger_with_meta, "~> 0.1"},
      {:pretty_log, "~> 0.1"},
      {:remote_ip, "~> 1.0"},
      {:skogsra, "~> 2.2"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      {:telemetry, "~> 1.0"},
      {:typed_ecto_schema, "~> 0.4"},
      {:xandra, "~> 0.19"}
    ]
  end

  defp astarte_lib(library_name) do
    base_directory = System.get_env("ASTARTE_LIBRARIES_PATH", "../../libs")
    Path.join(base_directory, library_name)
  end
end
