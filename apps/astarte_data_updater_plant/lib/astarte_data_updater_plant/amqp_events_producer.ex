defmodule Astarte.DataUpdaterPlant.AMQPEventsProducer do
  require Logger
  use GenServer

  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Exchange
  alias Astarte.DataUpdaterPlant.Config

  @connection_backoff 10000
  @exchange_name "astarte_events"

  # API

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # Server callbacks

  def init(_args) do
    rabbitmq_connect(false)
  end

  def terminate(_reason, %Channel{conn: conn} = chan) do
    Channel.close(chan)
    Connection.close(conn)
  end

  def handle_info({:try_to_connect}, _state) do
    {:ok, new_state} = rabbitmq_connect()
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _state) do
    Logger.warn("RabbitMQ connection lost: #{inspect(reason)}. Trying to reconnect...")
    {:ok, new_state} = rabbitmq_connect()
    {:noreply, new_state}
  end

  defp rabbitmq_connect(retry \\ true) do
    with {:ok, conn} <- Connection.open(Config.amqp_producer_options()),
         # Get notifications when the connection goes down
         Process.monitor(conn.pid),
         {:ok, chan} <- Channel.open(conn),
         :ok <- Exchange.declare(chan, @exchange_name, :direct, durable: true) do

      {:ok, chan}

    else
      {:error, reason} ->
        Logger.warn("RabbitMQ Connection error: #{inspect(reason)}")
        maybe_retry(retry)
      :error ->
        Logger.warn("Unknown RabbitMQ connection error")
        maybe_retry(retry)
    end
  end

  defp maybe_retry(retry) do
    if retry do
      Logger.warn("Retrying connection in #{@connection_backoff} ms")
      :erlang.send_after(@connection_backoff, :erlang.self(), {:try_to_connect})
      {:ok, :not_connected}
    else
      {:stop, :connection_failed}
    end
  end
end
