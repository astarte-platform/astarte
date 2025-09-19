import Config

config :cqerl,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST"), System.get_env("CASSANDRA_DB_PORT")}]

config :logger, :console,
  format: {Astarte.Import.LogFmtFormatter, :format},
  metadata: [:module, :function, :device_id, :realm]

config :logfmt,
  prepend_metadata: [:application, :module, :function, :realm, :device_id]
