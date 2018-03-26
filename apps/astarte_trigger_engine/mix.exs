#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.TriggerEngine.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_trigger_engine,
      version: "0.1.0",
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  defp astarte_required_modules("true") do
    [
      {:astarte_core, in_umbrella: true},
      {:astarte_data_access, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, git: "https://git.ispirata.com/Astarte-NG/astarte_core"},
      {:astarte_data_access, git: "https://git.ispirata.com/Astarte-NG/astarte_data_access"}
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Astarte.TriggerEngine.Application, []}
    ]
  end

  defp deps do
    [
      {:amqp, "~> 1.0.0-pre.2"},
      {:bbmustache, "~> 1.5"},
      {:conform, "~> 2.2"},
      {:cyanide, "~> 0.5.0"},
      {:cqex, github: "ispirata/cqex"},
      {:httpoison, "~> 1.0"},
      {:poison, "~> 3.1"},
      {:distillery, "~> 1.4", runtime: false},
      {:excoveralls, "~> 0.6", only: :test}
    ]
  end
end
