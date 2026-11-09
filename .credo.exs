%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: [
        {Credo.Check.Refactor.FilterFilter, false},
        {Credo.Check.Refactor.FilterReject, false},
        {Credo.Check.Refactor.RejectFilter, false},
        {Credo.Check.Refactor.RejectReject, false},

        {Credo.Check.Design.TagFIXME, [priority: :normal, exit_status: 0]},
        {Credo.Check.Design.TagTODO, [priority: :normal, exit_status: 0]},
        {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 100]}
      ]
    }
  ]
}
