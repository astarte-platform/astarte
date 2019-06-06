use Mix.Config

config :cqerl,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST"), System.get_env("CASSANDRA_DB_PORT")}]
