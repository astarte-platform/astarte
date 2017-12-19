use Mix.Config

config :astarte_rpc, :amqp_connection,
  host: "rabbitmq"

config :astarte_pairing, :broker_url,
  "ssl://broker.beta.astarte.cloud:8883/"

config :astarte_pairing, :cfssl_url,
  System.get_env("CFSSL_API_URL") || "http://ispirata-docker-alpine-cfssl-autotest:8080"

config :cqerl, :cassandra_nodes,
  [{System.get_env("CASSANDRA_DB_HOST") || "scylladb-scylla", System.get_env("CASSANDRA_DB_PORT") || 9042}]
