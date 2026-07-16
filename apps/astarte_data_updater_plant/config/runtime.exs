import Config

level = System.get_env("ASTARTE_LOG_LEVEL")

if level do
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
