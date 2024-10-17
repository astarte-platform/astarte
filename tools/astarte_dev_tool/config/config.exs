import Config

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [:realm, :datacenter, :replication_factor, :module, :function, :tag]

config :astarte_dev_tool, :xandra,
  nodes: [
    "#{System.get_env("CASSANDRA_DB_HOST") || "localhost"}:#{System.get_env("CASSANDRA_DB_PORT") || 9042}"
  ],
  sync_connect: 5000,
  log: :info,
  stacktrace: true,
  pool_size: 10
