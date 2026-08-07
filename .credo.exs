%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: [
        {Credo.Check.Design.TagFIXME, [priority: :normal, exit_status: 0]},
        {Credo.Check.Design.TagTODO, [priority: :normal, exit_status: 0]},
        {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 100]}
      ]
    }
  ]
}
