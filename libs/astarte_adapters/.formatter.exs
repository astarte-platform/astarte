# Used by "mix format"
locals_without_parens = [
  transform: 2,
  transform: 3,
  pre_process: 1,
  keep: :*,
  field: 2,
  field: 3,
  post_process: 1
]

[
  inputs: [
    "lib/**/*.{ex,exs}",
    "test/**/*.{ex,exs}",
    "mix.exs"
  ],
  import_deps: [:stream_data],
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
