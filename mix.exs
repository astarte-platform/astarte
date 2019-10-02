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

defmodule Astarte.DataAccess.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_data_access,
      version: "0.10.1",
      elixir: "~> 1.5",
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
      deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA")),
      source_url: "https://github.com/astarte-platform/astarte_data_access",
      homepage_url: "https://astarte-platform.org/"
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
      {:astarte_core, github: "astarte-platform/astarte_core", branch: "release-0.10"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cqerl,
       github: "matehat/cqerl", ref: "6e44b42df1cb0fcf82d8ab4df032c2e7cacb96f9", override: true},
      {:cqex, github: "matehat/cqex", ref: "a2c45667108f9b1e8a9c73c5250a04020bf72a30"},
      {:conform, "== 2.5.2"},
      {:dialyxir, "== 0.5.1", only: [:dev], runtime: false},
      {:excoveralls, "== 0.9.1", only: :test}
    ]
  end

  defp description do
    """
    Astarte Data Access defines astarte_data_access.cassandra_nodes config entry.
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
