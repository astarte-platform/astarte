#
# This file is part of Astarte.
#
# Copyright 2026 Ispirata Srl
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
defmodule Astarte.FDO.Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_fdo_core,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [plt_add_apps: [:ex_unit]],
      deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp astarte_required_modules("true") do
    [
      {:astarte_core, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, path: "../astarte_core", override: true}
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.10"},
      {:typed_ecto_schema, "~> 0.4"},
      {:cbor, "~> 1.0"},
      {:cose, github: "secomind/cose-elixir"},
      {:excoveralls, "~> 0.15", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mimic, "~> 1.11", only: :test},
      {:typedstruct, "~> 0.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
