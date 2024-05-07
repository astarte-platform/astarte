import Config

config :xandra,
  cassandra_table_page_sizes: [
    device_table_page_size: 10,
    individual_datastreams: 1000,
    object_datastreams: 1000,
    individual_properties: 1000
  ]

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [:module, :function, :device_id, :realm, :interface_id, :reason, :tag]

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]
