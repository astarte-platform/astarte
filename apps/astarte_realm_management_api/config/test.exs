use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :astarte_realm_management_api, Astarte.RealmManagement.API.Web.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :astarte_realm_management_api, :rpc_queue,
  "realm_management_rpc"
