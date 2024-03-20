import Config

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [:realm, :device_id, :ip_address, :module, :function, :tag]

config :astarte_data_updater_plant, :astarte_instance_id, ""
