import Config

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [
    :realm,
    :interface,
    :interface_major,
    :trigger_name,
    :policy_name,
    :module,
    :function,
    :tag
  ]

config :astarte_realm_management, :astarte_instance_id, "default"
