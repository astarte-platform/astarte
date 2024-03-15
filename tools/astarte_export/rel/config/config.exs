import Config

config :xandra,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST"), System.get_env("CASSANDRA_DB_PORT")}]

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
