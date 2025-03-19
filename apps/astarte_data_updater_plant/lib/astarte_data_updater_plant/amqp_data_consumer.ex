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
  defmodule State do
    defstruct [
      :channel,
      :monitor,
      :queue_name
    ]
  end

  require Logger
  use GenServer

  alias AMQP.Channel
  alias Astarte.Core.DecimicrosecondDateTime
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.DataUpdater

  # TODO should this be customizable?
  @reconnect_interval 1_000
  @adapter Config.amqp_adapter!()
  @msg_type_header "x_astarte_msg_type"
  @realm_header "x_astarte_realm"
  @device_id_header "x_astarte_device_id"
  @ip_header "x_astarte_remote_ip"
  @control_path_header "x_astarte_control_path"
  @interface_header "x_astarte_interface"
  @path_header "x_astarte_path"
  @internal_path_header "x_astarte_internal_path"

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

  @impl true
  def init(args) do
    queue_name = Keyword.fetch!(args, :queue_name)
    {:ok, %State{queue_name: queue_name}, {:continue, :init_consume}}
  end

  @impl true
  def handle_continue(:init_consume, state), do: init_consume(state)

  @impl true
  def handle_call({:ack, delivery_tag}, _from, %State{channel: chan} = state) do
    res = @adapter.ack(chan, delivery_tag)
    {:reply, res, state}
  end

  def handle_call({:discard, delivery_tag}, _from, %State{channel: chan} = state) do
    res = @adapter.reject(chan, delivery_tag, requeue: false)
    {:reply, res, state}
  end

  def handle_call({:requeue, delivery_tag}, _from, %State{channel: chan} = state) do
    res = @adapter.reject(chan, delivery_tag, requeue: true)
    {:reply, res, state}
  end

  def handle_call({:start_message_tracker, realm, device_id}, _from, state) do
    res = DataUpdater.get_message_tracker(realm, device_id)
    {:reply, res, state}
  end

  def handle_call({:start_data_updater, realm, device_id, message_tracker}, _from, state) do
    res = DataUpdater.get_data_updater_process(realm, device_id, message_tracker)
    {:reply, res, state}
  end

  @impl true
  def handle_info(:init_consume, state), do: init_consume(state)

  def handle_info(
        {:DOWN, _, :process, pid, :normal},
        %State{channel: %Channel{pid: chan_pid}} = state
      )
      when pid != chan_pid do
    # This is a Message Tracker deactivating itself normally, do nothing
    {:noreply, state}
  end

  # Make sure to handle monitored message trackers exit messages
  # Under the hood DataUpdater calls Process.monitor so those monitor are leaked into this process.
  def handle_info(
        {:DOWN, monitor, :process, chan_pid, reason},
        %{monitor: monitor, channel: %{pid: chan_pid}} = state
      ) do
    # Channel went down, stop the process
    Logger.warning("AMQP data consumer crashed, reason: #{inspect(reason)}",
      tag: "data_consumer_chan_crash"
    )

    init_consume(%State{state | channel: nil, monitor: nil})
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Message consumed
  def handle_info({:basic_deliver, payload, meta}, state) do
    %State{channel: chan} = state
    {headers, no_headers_meta} = Map.pop(meta, :headers, [])
    headers_map = amqp_headers_to_map(headers)
    msg_type = Map.get(headers_map, @msg_type_header, headers_map)

    {timestamp, clean_meta} = Map.pop(no_headers_meta, :timestamp)
    timestamp = DecimicrosecondDateTime.from_unix!(timestamp, :decimicrosecond)

    case handle_consume(msg_type, payload, headers_map, timestamp, clean_meta) do
      :ok ->
        :ok

      :invalid_msg ->
        # ACK invalid msg to discard them
        @adapter.ack(chan, meta.delivery_tag)
    end

    {:noreply, state}
  end

  defp schedule_connect() do
    Process.send_after(self(), :init_consume, @reconnect_interval)
  end

  defp init_consume(state) do
    conn = ExRabbitPool.get_connection_worker(:amqp_consumer_pool)

    case ExRabbitPool.checkout_channel(conn) do
      {:ok, channel} ->
        try_to_setup_consume(channel, conn, state)

      {:error, reason} ->
        _ =
          Logger.warning(
            "Failed to check out channel for consumer on queue #{state.queue_name}: #{inspect(reason)}",
            tag: "channel_checkout_fail"
          )

        schedule_connect()
        {:noreply, state}
    end
  end

  defp try_to_setup_consume(channel, conn, state) do
    %Channel{pid: channel_pid} = channel
    %State{queue_name: queue_name} = state

    with :ok <- @adapter.qos(channel, prefetch_count: Config.consumer_prefetch_count!()),
         {:ok, _queue} <- @adapter.declare_queue(channel, queue_name, durable: true),
         {:ok, _consumer_tag} <- @adapter.consume(channel, queue_name, self()) do
      ref = Process.monitor(channel_pid)

      _ =
        Logger.debug("AMQPDataConsumer for queue #{queue_name} initialized",
          tag: "data_consumer_init_ok"
        )

      {:noreply, %State{state | channel: channel, monitor: ref}}
    else
      {:error, reason} ->
        Logger.warning(
          "Error initializing AMQPDataConsumer on queue #{state.queue_name}: #{inspect(reason)}",
          tag: "data_consumer_init_err"
        )

        # Something went wrong, let's put the channel back where it belongs
        _ = ExRabbitPool.checkin_channel(conn, channel)
        schedule_connect()
        {:noreply, %{state | channel: nil, monitor: nil}}
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

  # TODO remove this when all heartbeats will be moved to internal
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

  defp handle_consume("internal", payload, headers, timestamp, meta) do
    with %{
           @realm_header => realm,
           @device_id_header => device_id,
           @internal_path_header => internal_path
         } <- headers,
         {:ok, tracking_id} <- get_tracking_id(meta) do
      # Following call might spawn processes and implicitly monitor them
      DataUpdater.handle_internal(
        realm,
        device_id,
        internal_path,
        payload,
        tracking_id,
        timestamp
      )
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
    timestamp = DecimicrosecondDateTime.to_unix(timestamp, :millisecond)

    Logger.warning(
      "Invalid AMQP message: #{inspect(Base.encode64(payload))} #{inspect(headers)} #{inspect(timestamp)} #{inspect(meta)}",
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
