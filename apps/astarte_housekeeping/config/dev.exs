use Mix.Config

config :astarte_data_access,
       :cassandra_nodes,
       System.get_env("ASTARTE_CASSANDRA_NODES") || "localhost"
