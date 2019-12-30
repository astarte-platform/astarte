defmodule AstarteExport.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarte_export,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
  [
      {:xml_builder, git: "https://github.com/joshnuss/xml_builder.git" },
      {:xandra, "~> 0.10"},
      {:logfmt, "~> 3.3"},
      {:astarte_core, github: "astarte-platform/astarte_core"},
      {:astarte_data_access, github: "astarte-platform/astarte_data_access"},
      {:distillery, "~> 2.0.0"}

      
    ]
  end
end
