defmodule Astarte.DataUpdaterPlant.AMQPDataConsumer do
  require Logger
  use GenServer

  alias AMQP.Basic
  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Queue
  alias Astarte.DataUpdaterPlant.Config

  @connection_backoff 10000

  @msg_type_header "x_astarte_msg_type"
  @realm_header "x_astarte_realm"
  @device_id_header "x_astarte_device_id"
  @ip_header "x_astarte_remote_ip"
  @control_path_header "x_astarte_control_path"
  @interface_header "x_astarte_interface"
  @path_header "x_astarte_path"

  # API

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def ack(delivery_tag) do
    GenServer.call(__MODULE__, {:ack, delivery_tag})
  end

  # Server callbacks

  def init(_args) do
    rabbitmq_connect(false)
  end

  def terminate(_reason, %Channel{conn: conn} = chan) do
    Channel.close(chan)
    Connection.close(conn)
  end

  def handle_call({:ack, delivery_tag}, _from, chan) do
    res = Basic.ack(chan, delivery_tag)
    {:reply, res, chan}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  # Message consumed
  def handle_info({:basic_deliver, payload, meta}, chan) do
    {headers, no_headers_meta} = Map.pop(meta, :headers, [])
    headers_map = amqp_headers_to_map(headers)
    msg_type = Map.get(headers_map, "x_astarte_msg_type", headers_map)

    {timestamp, clean_meta} = Map.pop(no_headers_meta, :timestamp)

    case handle_consume(msg_type, payload, headers_map, timestamp, clean_meta) do
      :ok ->
        # TODO: this should be done asynchronously by Data Updater
        Basic.ack(chan, meta.delivery_tag)
      :invalid_msg ->
        # ACK invalid msg to discard them
        Basic.ack(chan, meta.delivery_tag)
      _ ->
        # ACK everything else for now, TODO: add other handle_consume return values
        Basic.ack(chan, meta.delivery_tag)
    end

    {:noreply, chan}
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
    with {:ok, conn} <- Connection.open(Config.amqp_options()),
         # Get notifications when the connection goes down
         Process.monitor(conn.pid),
         {:ok, chan} <- Channel.open(conn),
         {:ok, _queue} <- Queue.declare(chan, Config.queue_name(), durable: true),
         {:ok, _consumer_tag} <- Basic.consume(chan, Config.queue_name()) do

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

  defp handle_consume("connection", payload, headers, timestamp, meta) do
    with %{
            @realm_header => realm,
            @device_id_header => device_id,
            @ip_header => ip_address
          } <- headers do

      Astarte.DataUpdaterPlant.DataUpdater.handle_connection(realm, device_id, ip_address, meta.delivery_tag, timestamp)
    else
      _ -> handle_invalid_msg(payload, headers, timestamp, meta)
    end
  end

  defp handle_consume("disconnection", payload, headers, timestamp, meta) do
    with %{
            @realm_header => realm,
            @device_id_header => device_id
          } <- headers do

      Astarte.DataUpdaterPlant.DataUpdater.handle_disconnection(realm, device_id, meta.delivery_tag, timestamp)
    else
      _ -> handle_invalid_msg(payload, headers, timestamp, meta)
    end
  end

  defp handle_consume("introspection", payload, headers, timestamp, meta) do
    with %{
            @realm_header => realm,
            @device_id_header => device_id
          } <- headers do

      Astarte.DataUpdaterPlant.DataUpdater.handle_introspection(realm, device_id, payload, meta.delivery_tag, timestamp)
    else
      _ -> handle_invalid_msg(payload, headers, timestamp, meta)
    end
  end

  defp handle_consume("data", payload, headers, timestamp, meta) do
    with %{
            @realm_header => realm,
            @device_id_header => device_id,
            @interface_header => interface,
            @path_header => path
          } <- headers do

      Astarte.DataUpdaterPlant.DataUpdater.handle_data(realm, device_id, interface, path, payload, meta.delivery_tag, timestamp)
    else
      _ -> handle_invalid_msg(payload, headers, timestamp, meta)
    end
  end

  defp handle_consume("control", payload, headers, timestamp, meta) do
    with %{
            @realm_header => realm,
            @device_id_header => device_id,
            @control_path_header => control_path
          } <- headers do

      Astarte.DataUpdaterPlant.DataUpdater.handle_control(realm, device_id, control_path, payload, meta.delivery_tag, timestamp)
    else
      _ -> handle_invalid_msg(payload, headers, timestamp, meta)
    end
  end

  defp handle_consume(_msg_type, payload, headers, timestamp, meta) do
    handle_invalid_msg(payload, headers, timestamp, meta)
  end

  defp handle_invalid_msg(payload, headers, timestamp, meta) do
    Logger.warn("Invalid AMQP message: #{inspect(payload)} #{inspect(headers)} #{inspect(timestamp)} #{inspect(meta)}")
    :invalid_msg
  end

  defp amqp_headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {key, _type, value}, acc ->
      Map.put(acc, key, value)
    end)
  end
end
