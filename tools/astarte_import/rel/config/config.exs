import Config

cassandra_db_host = System.get_env("CASSANDRA_DB_HOST") || raise "CASSANDRA_DB_HOST not set"
cassandra_db_port = System.get_env("CASSANDRA_DB_PORT") || raise "CASSANDRA_DB_PORT not set"

config :cqerl,
  cassandra_nodes: [{cassandra_db_host, cassandra_db_port}]
