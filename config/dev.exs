import Config

config :phoenix, :stacktrace_depth, 20

config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  http: [port: 4002],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :astarte_housekeeping, Astarte.HousekeepingWeb.Endpoint,
  http: [port: 4001],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :astarte_pairing, Astarte.PairingWeb.Endpoint,
  http: [port: 4003],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :astarte_realm_management, Astarte.RealmManagementWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :astarte_pairing, :broker_url, "mqtts://broker.beta.astarte.cloud:8883/"

config :astarte_pairing, :cfssl_url, "http://localhost:8888"

config :astarte_fdo, :base_url_domain, "api.astarte.localhost"
config :astarte_fdo, :base_url_port, 4003
config :astarte_fdo, :base_url_protocol, :http
config :astarte_pairing, :enable_credential_reuse, true

config :astarte_pairing, vault_authentication_mechanism: :token
config :astarte_pairing, vault_token: "astarte_token"

config :astarte_vmq_plugin, :registry_mfa, {Astarte.VMQ.Plugin.Utils, :empty_plugin_functions, []}
