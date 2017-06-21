defmodule Housekeeping.AMQP do
  require Logger
  use GenServer
  use AMQP

  @connection_backoff 10000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :housekeeping_amqp)
  end

  def init(_opts) do
    rabbitmq_connect(false)
  end

  def publish(exchange, routing_key, payload, options \\ []) do
    GenServer.cast(:housekeeping_amqp, {:publish, exchange, routing_key, payload, options})
  end

  def ack(tag) do
    GenServer.cast(:housekeeping_amqp, {:ack, tag})
  end

  def reject(tag) do
    GenServer.cast(:housekeeping_amqp, {:reject, tag})
  end

  defp rabbitmq_connect(retry \\ true) do
    with {:ok, options} <- Application.fetch_env(:housekeeping_engine, :amqp),
         {:ok, conn} <- Connection.open(options),
         # Get notifications when the connection goes down
         Process.monitor(conn.pid),
         # We link the connection to this process, that way if we die the connection dies too
         # This is useful since unacked messages are requeued only after the connection is dead
         Process.link(conn.pid),
         {:ok, chan} <- Channel.open(conn),
         {:ok, _consumer_tag} <- Basic.consume(chan, Keyword.get(options, :rpc_queue)) do
      {:ok, chan}

    else
      {:error, reason} ->
        Logger.warn("RabbitMQ Connection error: " <> inspect(reason))
        maybe_retry(retry)
      :error ->
        Logger.warn("Unknown RabbitMQ connection error")
        maybe_retry(retry)
    end
  end

  defp maybe_retry(retry) do
    if retry do
      :timer.sleep(@connection_backoff)
      rabbitmq_connect()
    else
      {:ok, nil}
    end
  end

  # Server callbacks

  def handle_cast({:publish, exchange, routing_key, payload, options}, chan) do
    Basic.publish(chan, exchange, routing_key, payload, options)
    {:noreply, chan}
  end

  def handle_cast({:ack, tag}, chan) do
    Basic.ack(chan, tag)
  end

  def handle_cast({:reject, tag}, chan) do
    Basic.reject(chan, tag)
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, chan) do
    {:stop, :normal, chan}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, chan) do
    # We process the message asynchronously
    spawn_link fn -> consume(tag, redelivered, payload) end
    {:noreply, chan}
  end

  # This callback should try to reconnect to the server
  def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
    {:ok, chan} = rabbitmq_connect()
    {:noreply, chan}
  end

  defp consume(_tag, _redelivered, _payload) do
    # TODO: do stuff
    :ok
  end
end
