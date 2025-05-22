defmodule Doc.MixProject do
  use Mix.Project

  @source_ref "release-1.0"

  def project do
    source_version =
      String.replace_prefix(@source_ref, "release-", "")
      |> String.replace("master", "snapshot")

    [
      app: :doc,
      version: "1.3.0-dev",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Clea Astarte",
      homepage_url: "https://docs.astarte-platform.org/astarte/#{source_version}/",
      source_url: "https://github.com/astarte-platform/astarte",
      docs: docs()
    ]
  end

  defp deps do
    [{:ex_doc, "~> 0.29", only: :dev}]
  end

  # Add here additional documentation files
  defp docs do
    [
      main: "001-intro_user",
      logo: "images/clea_bw.png",
      # It's in the docs repo root
      javascript_config_path: "../common_vars.js",
      extras: Path.wildcard("pages/*/*.md"),
      assets: "images/",
      api_reference: false,
      source_ref: "#{@source_ref}/doc",
      groups_for_extras: [
        "Architecture, Design and Concepts": ~r"/architecture/",
        "User Guide": ~r"/user/",
        "Administrator Guide": ~r"/administrator/",
        Tutorials: ~r"/tutorials/",
        "API Reference": ~r"/api/"
      ],
      groups_for_modules: [
        "App Engine": ~r"Astarte.AppEngine",
        Core: ~r"Astarte.Core",
        Housekeeping: ~r"Astarte.Housekeeping",
        Pairing: ~r"Astarte.Pairing",
        "Realm Management": ~r"Astarte.RealmManagement",
        RPC: ~r"Astarte.RPC"
      ]
    ]
  end
end
