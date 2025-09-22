defmodule Astarte.Import.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_import,
      version: "1.2.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :xmerl]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:xandra, "~> 0.19.4"},
      {:exandra, "~>0.16.0"},
      {:ecto, "~>3.13"},
      {:logfmt, "~> 3.3"},
      {:astarte_core, github: "astarte-platform/astarte_core", branch: "release-1.3"},
      {:astarte_data_access, path: "../../libs/astarte_data_access"},
      {:jason, "~> 1.4"},
      {:distillery, "~> 2.0"},
      # Workaround for Elixir 1.15 / ssl_verify_fun issue
      # See also: https://github.com/deadtrickster/ssl_verify_fun.erl/pull/27
      {:ssl_verify_fun, "~> 1.1.0", manager: :rebar3, override: true}
    ]
  end
end
