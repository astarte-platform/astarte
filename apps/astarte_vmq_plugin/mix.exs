#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

defmodule Astarte.VMQ.Plugin.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_vmq_plugin,
      # x-release-please-start-version
      version: "1.5.0-dev",
      # x-release-please-end
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_core_path: dialyzer_cache_directory(Mix.env()), plt_add_apps: [:ex_unit]],
      deps: deps()
    ]
  end

  def cli do
    [
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Astarte.VMQ.Plugin.Application, []},
      env: [
        vmq_plugin_hooks: [
          {:auth_on_publish, Astarte.VMQ.Plugin, :auth_on_publish, 6, []},
          {:auth_on_register, Astarte.VMQ.Plugin, :auth_on_register, 5, []},
          {:auth_on_subscribe, Astarte.VMQ.Plugin, :auth_on_subscribe, 3, []},
          {:on_client_offline, Astarte.VMQ.Plugin, :on_client_offline, 1, []},
          {:on_client_gone, Astarte.VMQ.Plugin, :on_client_gone, 1, []},
          {:on_publish, Astarte.VMQ.Plugin, :on_publish, 6, []},
          {:on_register, Astarte.VMQ.Plugin, :on_register, 3, []}
        ]
      ]
    ]
  end

  # Compile order is important to make sure support files are available when testing
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer_cache_directory(:ci) do
    "dialyzer_cache"
  end

  defp dialyzer_cache_directory(_) do
    nil
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:astarte_core, path: astarte_lib("astarte_core")},
      {:amqp, "~> 4.1"},
      {:vernemq_dev, github: "vernemq/vernemq_dev"},
      {:excoveralls, "~> 0.15", only: :test},
      {:typedstruct, github: "saleyn/typedstruct", override: true},
      {:mississippi, github: "secomind/mississippi"},
      {:pretty_log, "~> 0.1"},
      {:flatlog, github: "annopaolo/flatlog"},
      # https://github.com/elixir-horde/horde/pull/291
      {:horde, github: "noaccOS/horde", branch: "push-ozyqtonylvpv"},
      {:dialyxir, "~> 1.4", only: [:dev, :ci, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:xandra, "~> 0.20"},
      {:castore, "~> 1.0"},
      {:astarte_generators, path: astarte_lib("astarte_generators"), only: [:dev, :test]},
      {:mimic, "~> 2.0", only: :test},
      {:mox, "~> 1.3", only: :test}
    ]
  end

  defp astarte_lib(library_name) do
    base_directory = System.get_env("ASTARTE_LIBRARIES_PATH", "../../libs")
    Path.join(base_directory, library_name)
  end
end
