[
  inputs: [
    "lib/**/*.{ex,exs}",
    "test/**/*.{ex,exs}",
    "mix.exs"
  ],
  subdirectories: ["priv/*/migrations", "priv/*/migrations/realm", "priv/*/migrations/astarte"],
  import_deps: [:skogsra, :ecto, :ecto_sql, :astarte_generators]
]
