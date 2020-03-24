use Mix.Config

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [
    :realm,
    :interface,
    :interface_major,
    :trigger_name,
    :module,
    :function,
    :tag
  ]
