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
#

defmodule Astarte.Core.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_core,
      version: "1.4.0-rc.0",
      elixir: "~> 1.15",
      build_embedded: Mix.env() == :prod,
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
      dialyzer: [plt_core_path: dialyzer_cache_directory(Mix.env())],
      deps: deps(),
      source_url: "https://github.com/astarte-platform/astarte_core",
      homepage_url: "https://astarte-platform.org/"
    ]
  end

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  defp dialyzer_cache_directory(:ci) do
    "dialyzer_cache"
  end

  defp dialyzer_cache_directory(_) do
    nil
  end

  defp deps do
    [
      {:cyanide, "~> 2.0"},
      {:ecto, "~> 3.4"},
      {:ecto_morph, "~> 0.1.23"},
      {:typed_ecto_schema, "~> 0.4"},
      {:typedstruct, "~> 0.5"},
      {:protobuf, "~> 0.15"},
      {:jason, "~> 1.2"},
      {:elixir_uuid, "~> 1.2"},
      {:excoveralls, "~> 0.15", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test, :ci], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Astarte Core library.
    """
  end

  defp package do
    [
      maintainers: ["Davide Bettio", "Riccardo Binetti"],
      licenses: ["Apache-2.0"],
      links: %{
        "Astarte" => "https://astarte-platform.org",
        "Ispirata" => "https://ispirata.com",
        "GitHub" => "https://github.com/astarte-platform/astarte_core"
      }
    ]
  end
end
