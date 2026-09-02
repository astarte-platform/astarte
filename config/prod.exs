import Config

config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  server: true,
  version: Application.spec(:astarte_appengine_api, :vsn)
