#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.AMQPTriggersProducer do
  @moduledoc """
    AMQP producer for Astarte triggers.

    This module is responsible for publishing messages related to triggers
    to the AMQP broker. It uses a GenServer to manage the connection and
    publishing logic.
  """

  require Logger
  use GenServer

  alias AMQP.Channel
  alias Astarte.DataUpdaterPlant.Config

  @connection_backoff 10000
  @adapter Config.amqp_adapter!()

  # Publisc API

  @doc """
    Starts the AMQP triggers producer GenServer.
    It initializes the connection to the AMQP broker and prepares it for publishing messages.
    The `args` parameter can be used to pass additional configuration options if needed.
  """
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
    Publishes a message to the specified exchange with the given routing key and payload.
    The `opts` parameter can be used to specify additional options for the message.
    It uses a longer timeout to allow RabbitMQ to process requests even if loaded.

    ## Parameters
    - `exchange`: The name of the exchange to publish the message to.
    - `routing_key`: The routing key to use for the message.
    - `payload`: The message payload to be sent.
    - `opts`: Additional options for the message, such as headers or delivery mode. These will be passed to the AMQP adapter.
  """
  def publish(exchange, routing_key, payload, opts) do
    # Use a longer timeout to allow RabbitMQ to process requests even if loaded
    GenServer.call(__MODULE__, {:publish, exchange, routing_key, payload, opts}, 60_000)
  end

  @doc """
    Declares an exchange in RabbitMQ.
    This is necessary to ensure that the exchange exists before publishing messages to it.
    The exchange is declared as durable and of type `:direct`.

    ## Parameters
    - `exchange`: The name of the exchange to declare.

    This function uses a longer timeout to allow RabbitMQ to process requests even if loaded.
  """
  def declare_exchange(exchange) do
    # Use a longer timeout to allow RabbitMQ to process requests even if loaded
    GenServer.call(__MODULE__, {:declare_exchange, exchange}, 60_000)
  end

  @impl GenServer
  def init(_opts) do
    with {:error, reason} <- init_producer() do
      {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:publish, exchange, routing_key, payload, opts}, _from, chan) do
    reply = @adapter.publish(chan, exchange, routing_key, payload, opts)

    {:reply, reply, chan}
  end

  @impl GenServer
  def handle_call({:declare_exchange, exchange}, _from, chan) do
    # TODO: we need to decide who is responsible of deleting the exchange once it is
    # no longer needed
    reply = @adapter.declare_exchange(chan, exchange, type: :direct, durable: true)

    {:reply, reply, chan}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, _pid, reason}, _channel) do
    Logger.warning("RabbitMQ connection lost: #{inspect(reason)}. Trying to reconnect...",
      tag: "events_producer_conn_lost"
    )

    case init_producer() do
      {:ok, channel} ->
        {:noreply, channel}

      {:error, _reason} ->
        schedule_connect()
        {:noreply, :not_connected}
    end
  end

  defp init_producer() do
    conn = ExRabbitPool.get_connection_worker(:triggers_producer_pool)

    with {:ok, channel} <- checkout_channel(conn) do
      %Channel{pid: channel_pid} = channel
      Process.monitor(channel_pid)

      Logger.debug("AMQPEventsProducer initialized",
        tag: "event_producer_init_ok"
      )

      {:ok, channel}
    end
  end

  defp checkout_channel(conn) do
    with {:error, reason} <- ExRabbitPool.checkout_channel(conn) do
      Logger.warning(
        "Failed to check out channel for producer: #{inspect(reason)}",
        tag: "event_producer_channel_checkout_fail"
      )

      {:error, :event_producer_channel_checkout_fail}
    end
  end

  defp schedule_connect() do
    Logger.warning("Retrying connection in #{@connection_backoff} ms")
    Process.send_after(self(), :init, @connection_backoff)
  end
end
