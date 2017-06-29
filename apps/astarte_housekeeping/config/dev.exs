use Mix.Config

config :cqerl,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST"), System.get_env("CASSANDRA_DB_PORT")}]

config :astarte_housekeeping, :amqp_connection,
  username: "guest",
  password: "guest",
  hostname: "localhost",
  virtual_host: "/",
  port: 5672

config :astarte_housekeeping, :amqp_consumer,
  queue: "housekeeping_rpc",
  callback: &Housekeeping.Engine.process_rpc/1

# If SSL is needed add
# ssl_options: [cacertfile: '/path/to/testca/cacert.pem',
#               certfile: '/path/to/client/cert.pem',
#               keyfile: '/path/to/client/key.pem',
#               # only necessary with intermediate CAs
#               # depth: 2,
#               verify: :verify_peer,
#               fail_if_no_peer_cert: true]
