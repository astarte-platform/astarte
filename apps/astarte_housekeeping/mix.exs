defmodule HousekeepingEngine.Mixfile do
  use Mix.Project

  def project do
    [app: :housekeeping_engine,
     version: "0.1.0",
     build_path: "_build",
     config_path: "config/config.exs",
     deps_path: "deps",
     lockfile: "mix.lock",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [
      applications: [:cqex],
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:cqex, "~> 0.2.0"},
      {:cqerl, github: "matehat/cqerl"},
      {:re2, git: "https://github.com/tuncer/re2.git", tag: "v1.7.2", override: true},
      {:distillery, "~> 1.4"}
    ]
  end
end
