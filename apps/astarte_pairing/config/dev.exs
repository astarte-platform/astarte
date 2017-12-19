use Mix.Config

config :astarte_pairing, :broker_url,
  "ssl://broker.beta.astarte.cloud:8883/"

config :astarte_pairing, :cfssl_url,
  "http://localhost:8888"

config :cqerl, :cassandra_nodes,
  [{System.get_env("CASSANDRA_DB_HOST") || "localhost", System.get_env("CASSANDRA_DB_PORT") || 9042}]
