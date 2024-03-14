import Config

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [:function]

config :astarte_trigger_engine, :astarte_instance_id, "default"
