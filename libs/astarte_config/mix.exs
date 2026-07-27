defmodule Astarte.Config.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_config,
      version: "1.4.0-rc.2",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:skogsra, "~> 2.2"}
    ]
  end
end
