defmodule Astarte.RealmManagement.Mixfile do
  use Mix.Project

  def project do
    [app: :astarte_realm_management,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
     deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))]
  end

  def application do
    [
     extra_applications: [:logger],
     mod: {Astarte.RealmManagement, []}
    ]
  end

  defp astarte_required_modules("true") do
    [
      {:astarte_core, in_umbrella: true},
      {:astarte_rpc, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, git: "https://git.ispirata.com/Astarte-NG/astarte_core"},
      {:astarte_rpc, git: "https://git.ispirata.com/Astarte-NG/astarte_rpc"}
    ]
  end

  defp deps do
     [
       {:amqp, "~> 1.0.0-pre.1"},
       {:cqex, github: "ispirata/cqex"},
       {:exprotobuf, "~> 1.2.7"},
       {:distillery, "~> 1.4", runtime: false},
       {:excoveralls, "~> 0.6", only: :test}
     ]
  end
end
