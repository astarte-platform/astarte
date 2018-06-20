defmodule Astarte.Housekeeping.API.Mixfile do
  use Mix.Project

  def project do
    [app: :astarte_housekeeping_api,
     version: "0.0.1",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
     deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {Astarte.Housekeeping.API.Application, []},
     extra_applications: [:logger, :runtime_tools]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp astarte_required_modules("true") do
    [
      {:astarte_rpc, in_umbrella: true},
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_rpc, git: "https://git.ispirata.com/Astarte-NG/astarte_rpc"},
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:conform, "== 2.5.2"},
      {:ecto, "== 2.2.10"},
      {:phoenix, "== 1.3.2"},
      {:phoenix_pubsub, "== 1.0.2"},
      {:gettext, "~> 0.11"},
      {:cors_plug, "== 1.5.2"},
      {:cowboy, "== 1.1.2"},
      {:ranch, "== 1.4.0", override: true},
      {:guardian, github: "ispirata/guardian"},

      {:distillery, "== 1.5.2", runtime: false},
      {:excoveralls, "~> 0.6", only: :test}
    ]
  end
end
