import Config

config :logger, :console,
  format: {Astarte.Import.LogFmtFormatter, :format},
  metadata: [:module, :function, :device_id, :realm]

config :logfmt,
  prepend_metadata: [:application, :module, :function, :realm, :device_id]
