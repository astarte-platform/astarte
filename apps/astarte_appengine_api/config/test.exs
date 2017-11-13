use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  http: [port: 4001],
  server: false

config :cqerl,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST") || "scylladb-scylla", System.get_env("CASSANDRA_DB_PORT") || 9042}]

# Print only warnings and errors during test
config :logger, level: :warn

config :astarte_appengine_api, :mqtt_options,
  username: "autotest",
  password: "autotest",
  host: "localhost",
  port: 1883
