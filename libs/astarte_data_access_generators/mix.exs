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

defmodule Astarte.DataAccess.Generators.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_data_access_generators,
      version: "0.1.0",
      elixir: "~> 1.15.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps() ++ astarte_required_modules(),
      package: package(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp astarte_required_modules() do
    [
      {:astarte_generators, github: "astarte-platform/astarte_generators"},
      {:astarte_data_access,
       github: "astarte-platform/astarte_data_access", branch: "release-1.3"}
    ]
  end

  defp dialyzer,
    do: [
      plt_core_path: dialyzer_cache_directory(Mix.env()),
      plt_add_apps: [:ex_unit],
      ignore_warnings: "dialyzer.ignore-warnings",
      files: ["lib"]
    ]

  defp dialyzer_cache_directory(:ci), do: "dialyzer_cache"
  defp dialyzer_cache_directory(_), do: nil

  defp elixirc_paths(env) when env in [:test, :ci], do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:stream_data, "~> 1.1"},
      # Test section
      {:dialyxir, "~> 1.4", only: [:dev, :ci], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test, :ci], runtime: false},
      {:excoveralls, "~> 0.15", only: [:test, :ci]},
      {:mox, "~> 0.5", only: :test}
    ]
  end

  # Run "mix help licenses" to learn about licenses.
  defp package do
    [
      maintainers: ["Gabriele Ghio"],
      licenses: ["Apache-2.0"],
      links: %{
        "Astarte" => "https://astarte-platform.org",
        "GitHub" => "https://github.com/astarte-platform/astarte_data_access_generators"
      }
    ]
  end
end
