#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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
defmodule Astarte.Auth.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_auth,
      # x-release-please-start-version
      version: "1.5.0-dev",
      # x-release-please-end
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_apps: [:ex_unit]],
      deps: deps(),
      description: "Shared authentication and authorization code for Astarte services"
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:astarte_config, in_umbrella: true},
      {:absinthe, "~> 1.7"},
      {:absinthe_plug, "~> 1.5"},
      {:guardian, "~> 2.4"},
      {:jason, "~> 1.2"},
      {:plug, "~> 1.16"},
      {:skogsra, "~> 2.2"},
      {:castore, "~> 1.0"},
      {:pretty_log, "~> 0.1"},
      {:httpoison, "~> 3.0"},
      {:hackney, "~> 4.0", override: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.15", only: :test},
      {:mimic, "~> 2.4", only: :test},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end
end
