#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind srl
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

defmodule Astarte.DataAccess.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_data_access,
      version: "1.3.0-rc.1",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      description: description(),
      package: package(),
      dialyzer: [plt_add_apps: [:ex_unit]],
      deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA")),
      source_url: "https://github.com/astarte-platform/astarte_data_access",
      homepage_url: "https://astarte-platform.org/"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Astarte.DataAccess, []},
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
      {:astarte_core, github: "astarte-platform/astarte_core", tag: "v1.3.0-rc.1"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exandra, "~> 0.13"},
      {:typed_ecto_schema, "~> 0.4"},
      {:skogsra, "~> 2.2"},
      {:excoveralls, "~> 0.15", only: :test},
      {:castore, "~> 1.0.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mimic, "~> 2.3.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Astarte Data Access library.
    """
  end

  defp package do
    [
      maintainers: ["Davide Bettio", "Riccardo Binetti"],
      licenses: ["Apache-2.0"],
      links: %{
        "Astarte" => "https://astarte-platform.org",
        "Ispirata" => "https://ispirata.com",
        "GitHub" => "https://github.com/astarte-platform/astarte_data_access"
      }
    ]
  end
end
