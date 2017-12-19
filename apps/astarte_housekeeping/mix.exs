defmodule Astarte.Housekeeping.Mixfile do
  use Mix.Project

  def project do
    [
     app: :astarte_housekeeping,
     version: "0.1.0",
     build_path: "_build",
     config_path: "config/config.exs",
     deps_path: "deps",
     lockfile: "mix.lock",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
     deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Astarte.Housekeeping, []}
    ]
  end

  defp astarte_required_modules("true") do
    [
      {:astarte_rpc, in_umbrella: true},
      {:astarte_data_access, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_rpc, git: "https://git.ispirata.com/Astarte-NG/astarte_rpc"},
      {:astarte_data_access, git: "https://git.ispirata.com/Astarte-NG/astarte_data_access"}
    ]
  end

  defp deps do
    [
      {:cqex, github: "ispirata/cqex"},
      {:conform, "~> 2.2"},
      {:distillery, "~> 1.4", runtime: false},
      {:excoveralls, "~> 0.6", only: :test}
    ]
  end
end
