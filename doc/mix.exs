defmodule Doc.MixProject do
  use Mix.Project

  def project do
    [
      app: :doc,
      version: "0.11.4",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Astarte",
      homepage_url: "http://astarte-platform.org",
      docs: docs()
    ]
  end

  defp deps do
    [{:ex_doc, "~> 0.17", only: :dev}]
  end

  # Add here additional documentation files
  defp docs do
    [
      main: "001-intro_user",
      logo: "images/mascot.png",
      source_url: "https://git.ispirata.com/Astarte-NG/%{path}#L%{line}",
      javascript_config_path: "../common_vars.js", # It's in the docs repo root
      extras: Path.wildcard("pages/*/*.md"),
      assets: "images/",
      api_reference: false,
      groups_for_extras: [
        "Architecture, Design and Concepts": ~r"/architecture/",
        "User Guide": ~r"/user/",
        "Administrator Guide": ~r"/administrator/",
        Tutorials: ~r"/tutorials/",
        "REST API Reference": ~r"/api/"
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
