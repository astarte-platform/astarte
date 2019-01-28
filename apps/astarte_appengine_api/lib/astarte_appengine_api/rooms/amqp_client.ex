#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Rooms.AMQPClient do
  require Logger
  use GenServer

  alias AMQP.Basic
  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Exchange
  alias AMQP.Queue
  alias Astarte.AppEngine.API.Config
  alias Astarte.AppEngine.API.Rooms.EventsDispatcher

  @connection_backoff 10000
  @prefetch_count 300

  # API

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # Server callbacks

  def init(_args) do
    send(self(), :try_to_connect)
    {:ok, :not_connected}
  end

  def terminate(reason, %Channel{conn: conn} = chan) do
    Logger.warn(
      "Rooms.AMQPClient terminating with reason #{inspect(reason)}, closing Channel and Connection"
    )

    Channel.close(chan)
    Connection.close(conn)
  end

  def terminate(reason, :not_connected) do
    Logger.warn("Rooms.AMQPClient terminating with reason #{inspect(reason)}")
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
    Logger.debug("got event, payload: #{inspect(payload)} meta: #{inspect(meta)}")

    EventsDispatcher.dispatch(payload)

    # TODO: should we ack manually?
    Basic.ack(chan, meta.delivery_tag)

    {:noreply, chan}
  end

  def handle_info(:try_to_connect, _state) do
    {:ok, new_state} = connect()
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _, :process, chan_pid, reason}, %Channel{pid: chan_pid, conn: conn}) do
    Logger.warn("RabbitMQ channel crashed: #{inspect(reason)}. Trying to reopen...")

    %Connection{
      pid: conn_pid
    } = conn

    with true <- Process.alive?(conn_pid),
         {:ok, chan} <- setup_channel(conn) do
      {:noreply, chan}
    else
      # Connection process is dead
      false ->
        {:ok, new_state} = connect()
        {:noreply, new_state}

      # If setup_channel fails, we start a new connection, after closing the previous one
      _ ->
        Connection.close(conn)
        {:ok, new_state} = connect()
        {:noreply, new_state}
    end
  end

  defp connect do
    with {:ok, conn} <- Connection.open(Config.rooms_amqp_options()),
         {:ok, chan} <- setup_channel(conn) do
      {:ok, chan}
    else
      {:error, reason} ->
        Logger.warn("RabbitMQ Connection error: #{inspect(reason)}")
        retry_after(@connection_backoff)
        {:ok, :not_connected}

      _ ->
        Logger.warn("Unknown RabbitMQ connection error")
        retry_after(@connection_backoff)
        {:ok, :not_connected}
    end
  end

  defp setup_channel(%Connection{} = conn) do
    with {:ok, chan} <- Channel.open(conn),
         :ok <- Basic.qos(chan, prefetch_count: @prefetch_count),
         :ok <- Exchange.declare(chan, Config.rooms_events_routing_key(), :direct, durable: true),
         {:ok, _queue} <- Queue.declare(chan, Config.rooms_events_queue_name(), durable: true),
         :ok <-
           Queue.bind(
             chan,
             Config.rooms_events_queue_name(),
             Config.events_exchange_name(),
             routing_key: Config.rooms_events_routing_key()
           ),
         {:ok, _consumer_tag} <- Basic.consume(chan, Config.rooms_events_queue_name()),
         # Get notifications when the chan or the connection go down
         Process.monitor(chan.pid) do
      {:ok, chan}
    end
  end

  defp retry_after(backoff) do
    Logger.warn("Retrying connection in #{backoff} ms")
    :erlang.send_after(backoff, self(), :try_to_connect)
  end
end
