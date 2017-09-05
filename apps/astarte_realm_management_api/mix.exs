defmodule Astarte.RealmManagement.API.Mixfile do
  use Mix.Project

  def project do
    [app: :astarte_realm_management_api,
     version: "0.0.1",
     build_path: "_build",
     config_path: "config/config.exs",
     deps_path: "deps",
     lockfile: "mix.lock",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
     deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {Astarte.RealmManagement.API, []},
     extra_applications: [:logger, :runtime_tools]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

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
     {:phoenix, "~> 1.3.0-rc"},
     {:phoenix_pubsub, "~> 1.0"},
     {:gettext, "~> 0.11"},
     {:cowboy, "~> 1.0"},
     {:ecto, "~> 2.1"},
     {:distillery, "~> 1.4", runtime: false},
     {:excoveralls, "~> 0.6", only: :test}
    ]
  end
end
