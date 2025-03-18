import Config

cassandra_host = System.get_env("CASSANDRA_DB_HOST", "cassandra")

cassandra_port =
  System.get_env("CASSANDRA_DB_PORT", "9042")
  |> String.to_integer()

config :cqerl,
  cassandra_nodes: [{cassandra_host, cassandra_port}]

config :astarte_data_access,
  xandra_nodes: "#{cassandra_host}:#{cassandra_port}"
