import Config

config :cqerl,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST"), System.get_env("CASSANDRA_DB_PORT")}]

config :astarte_import, :cluster_name, :xandra

config :logger, :console,
  format: {Astarte.Import.LogFmtFormatter, :format},
  metadata: [:module, :function, :device_id, :realm, :db_action, :reason]

config :logfmt,
  user_friendly: true
