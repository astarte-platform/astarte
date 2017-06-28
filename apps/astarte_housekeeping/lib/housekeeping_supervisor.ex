defmodule Housekeeping.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do

    amqp_opts = Application.get_env(:housekeeping_engine, :amqp_connection)
    consumer_opts = Application.get_env(:housekeeping_engine, :amqp_consumer)

    children = [
      worker(Housekeeping.Engine, []),
      worker(AstarteCore.AMQPConnection, [amqp_opts, consumer_opts, Housekeeping.AMQP])
    ]

    supervise(children, strategy: :one_for_one)
  end

end
