import Config

service =
  case System.get_env("RELEASE_NAME") do
    name when is_binary(name) -> name
    _ -> if app = Mix.Project.config()[:app], do: Atom.to_string(app)
  end

appengine_port = System.get_env("APPENGINE_API_PORT", "4002") |> String.to_integer()

config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint, http: [port: appengine_port]

if level = System.get_env("ASTARTE_LOG_LEVEL") do
  allowed_levels = [
    "emergency",
    "alert",
    "critical",
    "error",
    "warning",
    "warn",
    "notice",
    "info",
    "debug",
    "all",
    "none"
  ]

  if level not in allowed_levels,
    do: raise(~s[Invalid value for ASTARTE_LOG_LEVEL: "#{level}"])

  config :logger, level: String.to_existing_atom(level)
end

case service do
  "astarte_appengine_api" ->
    config :astarte_rpc, :astarte_services, [:astarte_data_updater_plant, :astarte_vmq_plugin]

  _ ->
    :ok
end
