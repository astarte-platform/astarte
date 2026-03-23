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

defmodule AstarteSecrets.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_secrets,
      version: "1.4.0-dev",
      elixir: "~> 1.15",
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:ex_unit]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:astarte_data_access, path: "../astarte_data_access"},
      {:astarte_generators, path: "../astarte_generators", only: :test},
      {:castore, "~> 1.0"},
      {:cose, github: "secomind/cose-elixir"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :ci, :test], runtime: false},
      {:ecto, "~> 3.12"},
      {:excoveralls, "~> 0.15", only: :test},
      {:httpoison, "~> 2.2"},
      {:mimic, "~> 1.11", only: :test},
      {:skogsra, "~> 2.2"},
      {:typed_ecto_schema, "~> 0.4"},
      {:x509, "~> 0.8"}
    ]
  end
end
