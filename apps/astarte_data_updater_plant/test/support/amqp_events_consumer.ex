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

defmodule Astarte.DataUpdaterPlant.AMQPTestEventsConsumer do
  require Logger
  use GenServer

  alias AMQP.Basic
  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Exchange
  alias AMQP.Queue
  alias Astarte.DataUpdaterPlant.AMQPTestHelper

  @connection_backoff 10000

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
    {headers, other_meta} = Map.pop(meta, :headers, [])
    headers_map = amqp_headers_to_map(headers)

    AMQPTestHelper.notify_deliver(payload, headers_map, other_meta)

    # TODO: should we ack manually?
    Basic.ack(chan, meta.delivery_tag)

    {:noreply, chan}
  end

  def handle_info({:try_to_connect}, _state) do
    {:ok, new_state} = rabbitmq_connect()
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _state) do
    Logger.warning("RabbitMQ connection lost: #{inspect(reason)}. Trying to reconnect...")
    {:ok, new_state} = rabbitmq_connect()
    {:noreply, new_state}
  end

  defp rabbitmq_connect(retry \\ true) do
    with {:ok, conn} <- Connection.open(AMQPTestHelper.amqp_consumer_options()),
         # Get notifications when the connection goes down
         Process.monitor(conn.pid),
         {:ok, chan} <- Channel.open(conn),
         :ok <-
           Exchange.declare(chan, AMQPTestHelper.events_exchange_name(), :direct, durable: true),
         {:ok, _queue} <-
           Queue.declare(
             chan,
             AMQPTestHelper.events_queue_name(),
             durable: false,
             auto_delete: true
           ),
         :ok <-
           Queue.bind(
             chan,
             AMQPTestHelper.events_queue_name(),
             AMQPTestHelper.events_exchange_name(),
             routing_key: AMQPTestHelper.events_routing_key()
           ),
         {:ok, _consumer_tag} <- Basic.consume(chan, AMQPTestHelper.events_queue_name()) do
      {:ok, chan}
    else
      {:error, reason} ->
        Logger.warning("RabbitMQ Connection error: #{inspect(reason)}")
        maybe_retry(retry)

      :error ->
        Logger.warning("Unknown RabbitMQ connection error")
        maybe_retry(retry)
    end
  end

  defp maybe_retry(retry) do
    if retry do
      Logger.warning("Retrying connection in #{@connection_backoff} ms")
      :erlang.send_after(@connection_backoff, :erlang.self(), {:try_to_connect})
      {:ok, :not_connected}
    else
      {:stop, :connection_failed}
    end
  end

  defp amqp_headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {key, _type, value}, acc ->
      Map.put(acc, key, value)
    end)
  end
end
