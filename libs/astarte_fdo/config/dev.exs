import Config


cassandra_host = System.get_env("CASSANDRA_DB_HOST", "cassandra")

cassandra_port =
  System.get_env("CASSANDRA_DB_PORT", "9042")
  |> String.to_integer()

config :astarte_fdo,
  xandra_nodes: "#{cassandra_host}:#{cassandra_port}"
