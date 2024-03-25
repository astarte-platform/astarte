import Config

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :astarte_realm_management, :astarte_instance_id, ""

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [
    :realm,
    :module,
    :function,
    :tag
  ]
