import Config

config :logger, :console, format: {PrettyLog.LogfmtFormatter, :format}

config :logger, level: :info
