[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [url_env: :*],
  export: [locals_without_parens: [url_env: :*]],
  import_deps: [:skogsra, :astarte_generators]
]
