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
  use GenServer

  alias AMQP.Basic
  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Exchange
  alias AMQP.Queue
  alias Astarte.DataUpdaterPlant.AMQPTestHelper

  @connection_backoff 10000

  # API

  def start_link(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def ack(delivery_tag) do
    GenServer.call(__MODULE__, {:ack, delivery_tag})
  end

  # Server callbacks

  def init(args) do
    realm = Keyword.fetch!(args, :realm)
    helper_name = Keyword.fetch!(args, :helper_name)
    # initial_state = %{realm: realm, helper_name: helper_name}

    initial_state = %{realm: realm, helper_name: helper_name, conn: nil, chan: nil}

    {:ok, state} = rabbitmq_connect(initial_state, false)

    {:ok, state}
  end

  def terminate(_reason, %{conn: conn, chan: chan}) when not is_nil(conn) and not is_nil(chan) do
    Channel.close(chan)
    Connection.close(conn)
  end

  def terminate(_reason, _state) do
    :ok
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

  def handle_info({:basic_deliver, payload, meta}, state) do
    {headers, other_meta} = Map.pop(meta, :headers, [])
    headers_map = amqp_headers_to_map(headers)

    # Pass the realm to find the correct helper
    AMQPTestHelper.notify_deliver(state.helper_name, payload, headers_map, other_meta)

    Basic.ack(state.chan, meta.delivery_tag)

    {:noreply, state}
  end

  def handle_info({:try_to_connect}, state) do
    {:ok, new_state} = rabbitmq_connect(state)
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    {:ok, new_state} = rabbitmq_connect(state)
    {:noreply, new_state}
  end

  defp rabbitmq_connect(state, retry \\ true) do
    with {:ok, conn} <- Connection.open(AMQPTestHelper.amqp_consumer_options()),
         # Now we can monitor the connection pid since `conn` is established
         _monitor_ref <- Process.monitor(conn.pid),
         {:ok, chan} <- Channel.open(conn),
         :ok <- setup_amqp_resources(chan, state.realm) do
      # On success, put the connection and channel into the state
      {:ok, %{state | conn: conn, chan: chan}}
    else
      {:error, _reason} ->
        maybe_retry(retry)

      :error ->
        maybe_retry(retry)
    end
  end

  defp setup_amqp_resources(chan, realm) do
    with :ok <-
           Exchange.declare(chan, AMQPTestHelper.events_exchange_name(realm), :direct,
             durable: true
           ),
         {:ok, _queue} <-
           Queue.declare(
             chan,
             AMQPTestHelper.events_queue_name(realm),
             durable: true,
             auto_delete: false
           ),
         :ok <-
           Queue.bind(
             chan,
             AMQPTestHelper.events_queue_name(realm),
             AMQPTestHelper.events_exchange_name(realm),
             routing_key: AMQPTestHelper.events_routing_key(realm)
           ),
         {:ok, _consumer_tag} <- Basic.consume(chan, AMQPTestHelper.events_queue_name(realm)) do
      :ok
    end
  end

  defp maybe_retry(retry) do
    if retry do
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
