import Config

config :logger, level: :info

config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  server: true,
  version: Application.spec(:astarte_appengine_api, :vsn)

config :astarte_housekeeping, Astarte.HousekeepingWeb.Endpoint,
  server: true,
  version: Application.spec(:astarte_housekeeping, :vsn)

config :astarte_pairing, Astarte.PairingWeb.Endpoint,
  server: true,
  version: Application.spec(:astarte_pairing, :vsn)

config :astarte_realm_management, Astarte.RealmManagementWeb.Endpoint,
  server: true,
  version: Application.spec(:astarte_realm_management, :vsn)
