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

defmodule Astarte.TestSuite.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_test_suite,
      version: "0.1.0",
      elixir: "~> 1.15.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps() ++ astarte_required_modules(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
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
      {:astarte_generators, path: astarte_lib("astarte_generators")},
      {:astarte_data_access, path: astarte_lib("astarte_data_access")},
      {:astarte_data_access_generators, path: astarte_lib("astarte_data_access_generators")}
    ]
  end

  defp dialyzer,
    do: [
      plt_core_path: dialyzer_cache_directory(Mix.env()),
      plt_add_apps: [:ex_unit],
      ignore_warnings: "dialyzer.ignore-warnings",
      files: ["lib"]
    ]

  defp dialyzer_cache_directory(:test), do: "dialyzer_cache"
  defp dialyzer_cache_directory(_), do: nil

  defp elixirc_paths(env) when env in [:test], do: ["test/astarte/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:stream_data, "~> 1.1"},
      # Test section
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.15", only: [:test]},
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
        "GitHub" => "https://github.com/astarte-platform/astarte/libs/astarte_test_suite"
      }
    ]
  end

  defp astarte_lib(library_name) do
    base_directory = System.get_env("ASTARTE_LIBRARIES_PATH", "../../libs")
    Path.join(base_directory, library_name)
  end
end
