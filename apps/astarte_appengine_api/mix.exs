#
# This file is part of Astarte.
#
# Copyright 2017-2021 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_appengine_api,
      elixir: "~> 1.15",
      version: "1.2.1",
      elixirc_paths: elixirc_paths(Mix.env()),
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

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Astarte.AppEngine.API.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support", "test/support_v2", "lib"]
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
      {:astarte_core, "~> 1.2"},
      {:astarte_data_access, "~> 1.2"},
      {:astarte_rpc, "~> 1.2"}
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_view, "~> 2.0"},
      {:gettext, "~> 0.24"},
      {:plug_cowboy, "~> 2.1"},
      {:jason, "~> 1.2"},
      {:cors_plug, "~> 2.0"},
      {:ex_lttb, "~> 0.3"},
      {:cyanide, "~> 2.0"},
      {:guardian, "~> 2.3.2"},
      # Required by :phoenix_swagger, otherwise it fails finding ex_json_schema.app
      {:ex_json_schema, "~> 0.7"},
      {:phoenix_swagger, "~> 0.8"},
      {:xandra, "~> 0.13"},
      {:pretty_log, "~> 0.1"},
      {:plug_logger_with_meta, "~> 0.1"},
      {:telemetry, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:telemetry_metrics_prometheus_core, "~> 0.4"},
      {:skogsra, "~> 2.2"},
      {:castore, "~> 1.0.0"},
      {:observer_cli, "~> 1.5"},
      {:dialyxir, "~> 1.0", only: [:dev, :ci], runtime: false},
      # Workaround for Elixir 1.15 / ssl_verify_fun issue
      # See also: https://github.com/deadtrickster/ssl_verify_fun.erl/pull/27
      {:ssl_verify_fun, "~> 1.1.0", manager: :rebar3, override: true},
      # Test section
      {:excoveralls, "~> 0.15", only: :test},
      {:mox, "~> 0.5", only: :test},
      {:stream_data, "~> 0.5", only: :test}
    ]
  end
end
