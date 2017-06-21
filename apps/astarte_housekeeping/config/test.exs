use Mix.Config

config :cqerl, 
  cassandra_nodes: [{"cassandra", 9042}]

config :housekeeping_engine, :amqp,
  username: "guest",
  password: "guest",
  hostname: "localhost",
  virtual_host: "/",
  port: 5672,
  rpc_queue: "housekeeping_rpc"
