import Config

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [:realm, :device_id, :ip_address, :module, :function, :tag]

config :astarte_data_updater_plant, :astarte_instance_id, "default"
