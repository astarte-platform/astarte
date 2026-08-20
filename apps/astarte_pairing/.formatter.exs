[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [
    :absinthe,
    :ecto,
    :phoenix,
    :skogsra,
    :astarte_generators,
    :open_api_spex
  ]
]
