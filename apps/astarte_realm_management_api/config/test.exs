use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :astarte_realm_management_api, Astarte.RealmManagement.APIWeb.Endpoint,
  http: [port: 4001],
  server: false

config :astarte_rpc, :amqp_connection,
  host: "rabbitmq"

# Print only warnings and errors during test
config :logger, level: :warn
