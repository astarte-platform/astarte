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

defmodule Astarte.Core.Generators.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_generators,
      version: "0.1.0",
      elixir: "~> 1.15.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps() ++ astarte_required_modules(),
      package: package(),
      dialyzer: [plt_add_apps: [:ex_unit]],
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
      {:astarte_core, github: "astarte-platform/astarte_core", branch: "release-1.3"}
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:stream_data, "~> 1.1"},
      # Test section
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.15", only: :test},
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
        "GitHub" => "https://github.com/astarte-platform/astarte_generators"
      }
    ]
  end
end
