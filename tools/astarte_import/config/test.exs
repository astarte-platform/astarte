import Config

config :logger, :console,
  format: {Astarte.Import.LogFmtFormatter, :format},
  metadata: [:module, :function, :device_id, :realm, :db_action, :reason]

config :logfmt,
  user_friendly: true
