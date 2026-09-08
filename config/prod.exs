import Config

config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  server: true,
  version: Application.spec(:astarte_appengine_api, :vsn)

config :astarte_housekeeping, Astarte.HousekeepingWeb.Endpoint,
  server: true,
  version: Application.spec(:astarte_housekeeping, :vsn)

config :logger, level: :info
