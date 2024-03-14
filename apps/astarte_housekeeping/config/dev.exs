import Config

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [:realm, :datacenter, :replication_factor, :module, :function, :tag]

config :astarte_housekeeping, :astarte_instance_id, "default"
