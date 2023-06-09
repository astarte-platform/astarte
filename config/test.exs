import Config

config :cqerl,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST") || "cassandra", System.get_env("CASSANDRA_DB_PORT") || 9042}]
