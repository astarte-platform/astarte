use Mix.Config

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [:function]
