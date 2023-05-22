#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.DataUpdaterPlant.AMQPDataConsumer do
  require Logger
  use GenServer

  alias AMQP.Basic
  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Queue
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.AMQPDataConsumer.ConnectionManager

  @msg_type_header "x_astarte_msg_type"
  @realm_header "x_astarte_realm"
  @device_id_header "x_astarte_device_id"
  @ip_header "x_astarte_remote_ip"
  @control_path_header "x_astarte_control_path"
  @interface_header "x_astarte_interface"
  @path_header "x_astarte_path"

  # API

  def start_link(args \\ []) do
    index = Keyword.fetch!(args, :queue_index)
    GenServer.start_link(__MODULE__, args, name: get_queue_via_tuple(index))
  end

  def ack(pid, delivery_tag) do
    Logger.debug("Going to ack #{inspect(delivery_tag)}")
    GenServer.call(pid, {:ack, delivery_tag})
  end

  def discard(pid, delivery_tag) do
    Logger.debug("Going to discard #{inspect(delivery_tag)}")
    GenServer.call(pid, {:discard, delivery_tag})
  end

  def requeue(pid, delivery_tag) do
    Logger.debug("Going to requeue #{inspect(delivery_tag)}")
    GenServer.call(pid, {:requeue, delivery_tag})
  end

  def start_message_tracker(realm, encoded_device_id) do
    with {:ok, via_tuple} <- fetch_queue_via_tuple(realm, encoded_device_id) do
      GenServer.call(via_tuple, {:start_message_tracker, realm, encoded_device_id})
    end
  end

  def start_data_updater(realm, encoded_device_id, message_tracker) do
    with {:ok, via_tuple} <- fetch_queue_via_tuple(realm, encoded_device_id) do
      GenServer.call(via_tuple, {:start_data_updater, realm, encoded_device_id, message_tracker})
    end
  end

  defp get_queue_via_tuple(queue_index) when is_integer(queue_index) do
    {:via, Registry, {Registry.AMQPDataConsumer, {:queue_index, queue_index}}}
  end

  defp fetch_queue_via_tuple(realm, encoded_device_id)
       when is_binary(realm) and is_binary(encoded_device_id) do
    # This is the same sharding algorithm used in astarte_vmq_plugin
    # Make sure they stay in sync
    queue_index =
      {realm, encoded_device_id}
      |> :erlang.phash2(Config.data_queue_total_count!())

    if queue_index >= Config.data_queue_range_start!() and
         queue_index <= Config.data_queue_range_end!() do
      {:ok, get_queue_via_tuple(queue_index)}
    else
      # This device is handled by a differente DUP instance
      {:error, :unhandled_device}
    end
  end

  # Server callbacks

  def init(args) do
    queue_name = Keyword.fetch!(args, :queue_name)
    # Init asynchronously since we will wait for the AMQP connection
    send(self(), {:async_init, queue_name})
    {:ok, nil}
  end

  def terminate(reason, %Channel{conn: conn} = chan) do
    Logger.info("AMQPDataConsumer terminating due to reason: #{inspect(reason)}.",
      tag: "data_consumer_terminate"
    )

    Channel.close(chan)
    Connection.close(conn)
  end

  def handle_call({:ack, delivery_tag}, _from, chan) do
    res = Basic.ack(chan, delivery_tag)
    {:reply, res, chan}
  end

  def handle_call({:discard, delivery_tag}, _from, chan) do
    res = Basic.reject(chan, delivery_tag, requeue: false)
    {:reply, res, chan}
  end

  def handle_call({:requeue, delivery_tag}, _from, chan) do
    res = Basic.reject(chan, delivery_tag, requeue: true)
    {:reply, res, chan}
  end

  def handle_call({:start_message_tracker, realm, device_id}, _from, chan) do
    res = DataUpdater.get_message_tracker(realm, device_id)
    {:reply, res, chan}
  end

  def handle_call({:start_data_updater, realm, device_id, message_tracker}, _from, chan) do
    res = DataUpdater.get_data_updater_process(realm, device_id, message_tracker)
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
    msg_type = Map.get(headers_map, @msg_type_header, headers_map)

    {timestamp, clean_meta} = Map.pop(no_headers_meta, :timestamp)

    case handle_consume(msg_type, payload, headers_map, timestamp, clean_meta) do
      :ok ->
        :ok

      :invalid_msg ->
        # ACK invalid msg to discard them
        Basic.ack(chan, meta.delivery_tag)
    end

    {:noreply, chan}
  end

  def handle_info({:async_init, queue_name}, _state) do
    # This will block until Rabbit connection is up
    rabbitmq_connection = ConnectionManager.get_connection()

    {:ok, chan} = initialize_chan(rabbitmq_connection, queue_name)

    {:noreply, chan}
  end

  def handle_info(
        {:DOWN, _, :process, pid, :normal},
        %Channel{pid: chan_pid, conn: %Connection{pid: conn_pid}} = chan
      )
      when pid != chan_pid and pid != conn_pid do
    # This is a Message Tracker deactivating itself normally, do nothing
    {:noreply, chan}
  end

  # Make sure to handle monitored message trackers exit messages
  # Under the hood DataUpdater calls Process.monitor so those monitor are leaked into this process.
  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    # Channel went down, stop the process
    Logger.warn("AMQP channel crashed, reason: #{inspect(reason)}",
      tag: "data_consumer_chan_crash"
    )

    Channel.close(state)
    {:stop, reason}
  end

  defp initialize_chan(rabbitmq_connection, queue_name) do
    with {:ok, chan} <- Channel.open(rabbitmq_connection),
         # Get a message if the channel goes down
         Process.monitor(chan.pid),
         :ok <- Basic.qos(chan, prefetch_count: Config.consumer_prefetch_count!()),
         {:ok, _queue} <- Queue.declare(chan, queue_name, durable: true),
         {:ok, _consumer_tag} <- Basic.consume(chan, queue_name) do
      {:ok, chan}
    else
      {:error, reason} ->
        Logger.warn("Error initializing AMQPDataConsumer: #{inspect(reason)}",
          tag: "data_consumer_init_err"
        )

        {:stop, reason}
    end
  end

  defp handle_consume("connection", payload, headers, timestamp, meta) do
    with %{
           @realm_header => realm,
           @device_id_header => device_id,
           @ip_header => ip_address
         } <- headers,
         {:ok, tracking_id} <- get_tracking_id(meta) do
      # Following call might spawn processes and implicitly monitor them
      DataUpdater.handle_connection(
        realm,
        device_id,
        ip_address,
        tracking_id,
        timestamp
      )
    else
      _ -> handle_invalid_msg(payload, headers, timestamp, meta)
    end
  end

  defp handle_consume("disconnection", payload, headers, timestamp, meta) do
    with %{
           @realm_header => realm,
           @device_id_header => device_id
         } <- headers,
         {:ok, tracking_id} <- get_tracking_id(meta) do
      # Following call might spawn processes and implicitly monitor them
      DataUpdater.handle_disconnection(
        realm,
        device_id,
        tracking_id,
        timestamp
      )
    else
      _ -> handle_invalid_msg(payload, headers, timestamp, meta)
    end
  end

  defp handle_consume("heartbeat", payload, headers, timestamp, meta) do
    with %{
           @realm_header => realm,
           @device_id_header => device_id
         } <- headers,
         {:ok, tracking_id} <- get_tracking_id(meta) do
      # Following call might spawn processes and implicitly monitor them
      DataUpdater.handle_heartbeat(realm, device_id, tracking_id, timestamp)
    else
      _ -> handle_invalid_msg(payload, headers, timestamp, meta)
    end
  end

  defp handle_consume("introspection", payload, headers, timestamp, meta) do
    with %{
           @realm_header => realm,
           @device_id_header => device_id
         } <- headers,
         {:ok, tracking_id} <- get_tracking_id(meta) do
      # Following call might spawn processes and implicitly monitor them
      DataUpdater.handle_introspection(
        realm,
        device_id,
        payload,
        tracking_id,
        timestamp
      )
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
         } <- headers,
         {:ok, tracking_id} <- get_tracking_id(meta) do
      # Following call might spawn processes and implicitly monitor them
      DataUpdater.handle_data(
        realm,
        device_id,
        interface,
        path,
        payload,
        tracking_id,
        timestamp
      )
    else
      _ -> handle_invalid_msg(payload, headers, timestamp, meta)
    end
  end

  defp handle_consume("control", payload, headers, timestamp, meta) do
    with %{
           @realm_header => realm,
           @device_id_header => device_id,
           @control_path_header => control_path
         } <- headers,
         {:ok, tracking_id} <- get_tracking_id(meta) do
      # Following call might spawn processes and implicitly monitor them
      DataUpdater.handle_control(
        realm,
        device_id,
        control_path,
        payload,
        tracking_id,
        timestamp
      )
    else
      _ -> handle_invalid_msg(payload, headers, timestamp, meta)
    end
  end

  defp handle_consume(_msg_type, payload, headers, timestamp, meta) do
    handle_invalid_msg(payload, headers, timestamp, meta)
  end

  defp handle_invalid_msg(payload, headers, timestamp, meta) do
    Logger.warn(
      "Invalid AMQP message: #{inspect(payload)} #{inspect(headers)} #{inspect(timestamp)} #{inspect(meta)}",
      tag: "data_consumer_invalid_msg"
    )

    :invalid_msg
  end

  defp amqp_headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {key, _type, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp get_tracking_id(meta) do
    message_id = meta.message_id
    delivery_tag = meta.delivery_tag

    if is_binary(message_id) and is_integer(delivery_tag) do
      {:ok, {meta.message_id, meta.delivery_tag}}
    else
      {:error, :invalid_message_metadata}
    end
  end
end
