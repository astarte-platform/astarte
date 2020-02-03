# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# third-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :astarte_export, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:astarte_export, :key)
#
# You can also configure a third-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#

config :xandra,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST"), System.get_env("CASSANDRA_DB_PORT")}]

config :xandra,
  cassandra_table_page_sizes: [device_table_page_size: 10,
                               individual_datastreams: 1000,
                               object_datastreams: 1000,
                               individual_properties: 1000]

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format}, 
  metadata: [:module, :function, :device_id, :realm, :interface_id, :reason, :tag]

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

