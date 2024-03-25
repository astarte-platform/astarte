import Config

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :astarte_housekeeping, :astarte_instance_id, ""

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [:realm, :datacenter, :replication_factor, :module, :function, :tag]
