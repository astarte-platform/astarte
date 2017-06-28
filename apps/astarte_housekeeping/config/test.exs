use Mix.Config

config :cqerl, 
  cassandra_nodes: [{"cassandra", 9042}]

config :housekeeping_engine, :amqp_connection,
  username: "guest",
  password: "guest",
  hostname: "rabbitmq",
  virtual_host: "/",
  port: 5672

config :housekeeping_engine, :amqp_consumer,
  queue: "housekeeping_rpc",
  callback: &Housekeeping.Engine.process_rpc/1
