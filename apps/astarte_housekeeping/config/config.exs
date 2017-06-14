# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :housekeeping_engine, :amqp,
  username: "guest",
  password: "guest",
  hostname: "localhost",
  virtual_host: "/",
  port: 5672,
  rpc_queue: "housekeeping_rpc"

# If SSL is needed add
# ssl_options: [cacertfile: '/path/to/testca/cacert.pem',
#               certfile: '/path/to/client/cert.pem',
#               keyfile: '/path/to/client/key.pem',
#               # only necessary with intermediate CAs
#               # depth: 2,
#               verify: :verify_peer,
#               fail_if_no_peer_cert: true]


# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :housekeeping_engine, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:housekeeping_engine, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#

import_config "#{Mix.env}.exs"
