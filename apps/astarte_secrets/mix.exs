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

  @external_resource Path.join(__DIR__, "../../VERSION")
  @version File.read!(Path.join(__DIR__, "../../VERSION")) |> String.trim()

  def project do
    [
      app: :astarte_secrets,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20",
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:xandra, github: "whatyouhide/xandra", override: true},
      {:exandra, github: "vinniefranco/exandra", override: true},
      {:cyanide, github: "noaccOS/cyanide", branch: "push-wuxvrvwqsrxv", override: true},
      {:astarte_core, github: "astarte-platform/astarte_core", override: true},
      {:typedstruct, github: "saleyn/typedstruct", override: true},
      {:pretty_log, "~> 0.1"},
      {:astarte_config, in_umbrella: true},
      {:astarte_data_access, in_umbrella: true},
      {:astarte_generators, in_umbrella: true, only: [:dev, :test]},
      {:castore, "~> 1.0"},
      {:cose, github: "secomind/cose-elixir"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ecto, "~> 3.12"},
      {:excoveralls, "~> 0.15", only: :test},
      {:mimic, "~> 2.3", only: :test},
      {:skogsra, "~> 2.2"},
      {:typed_ecto_schema, "~> 0.4"},
      {:x509, "~> 0.8"},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      # TODO: Remove override when exandra includes the fix for the issue with decimal 2.0
      {:decimal, "~> 3.0", override: true},
      {:httpoison, "~> 3.0", override: true},
      {:hackney, github: "benoitc/hackney", override: true}
    ]
  end
end
