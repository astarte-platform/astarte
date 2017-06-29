defmodule Astarte.Housekeeping.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do

    amqp_opts = Application.get_env(:astarte_housekeeping, :amqp_connection)
    consumer_opts = Application.get_env(:astarte_housekeeping, :amqp_consumer)

    children = [
      worker(Astarte.Housekeeping.Engine, []),
      worker(Astarte.Core.AMQPConnection, [amqp_opts, consumer_opts, Astarte.Housekeeping.AMQP])
    ]

    supervise(children, strategy: :one_for_one)
  end

end
