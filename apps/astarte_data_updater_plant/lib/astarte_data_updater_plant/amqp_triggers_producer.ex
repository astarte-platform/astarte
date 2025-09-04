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
  use GenServer, restart: :transient

  alias AMQP.{Channel, Connection}
  alias Astarte.DataUpdaterPlant.Config

  @connection_backoff 10_000
  @adapter Config.amqp_adapter!()

  @doc """
    Starts the AMQP triggers producer GenServer.
    It initializes the connection to the AMQP broker and prepares it for publishing messages.
    The `args` parameter can be used to pass additional configuration options if needed.
  """
  def start_link(args \\ []) do
    realm_name = Keyword.fetch!(args, :realm)
    server = Keyword.fetch!(args, :server)

    Logger.info("AMQPTriggers producer start link for realm #{realm_name}",
      tag: "amqp_triggers_consumer_start_link"
    )

    GenServer.start_link(__MODULE__, args, name: server)
  end

  @doc """
    Publishes a message to the specified exchange with the given routing key and payload.
    The `opts` parameter can be used to specify additional options for the message.
    It uses a longer timeout to allow RabbitMQ to process requests even if loaded.

    ## Parameters
    - `server`: The server handle for the specific realm interested to this exchange.
    - `exchange`: The name of the exchange to publish the message to.
    - `routing_key`: The routing key to use for the message.
    - `payload`: The message payload to be sent.
    - `opts`: Additional options for the message, such as headers or delivery mode. These will be passed to the AMQP adapter.

  """
  def publish(server, exchange, routing_key, payload, opts) do
    # Use a longer timeout to allow RabbitMQ to process requests even if loaded
    GenServer.call(server, {:publish, exchange, routing_key, payload, opts}, 60_000)
  end

  @doc """
    Declares an exchange in RabbitMQ.
    This is necessary to ensure that the exchange exists before publishing messages to it.
    The exchange is declared as durable and of type `:direct`.

    ## Parameters
    - `server`: The server handle for the specific realm interested to this exchange.
    - `exchange`: The name of the exchange to declare.
    This function uses a longer timeout to allow RabbitMQ to process requests even if loaded.
  """
  def declare_exchange(server, exchange) when is_binary(exchange) do
    # Use a longer timeout to allow RabbitMQ to process requests even if loaded
    GenServer.call(
      server,
      {:declare_exchange, exchange},
      60_000
    )
  end

  @impl GenServer
  def init(opts) when is_list(opts) do
    realm_name = Keyword.fetch!(opts, :realm)

    Logger.info("AMQPTriggers producer init for realm #{realm_name}.",
      tag: "amqp_triggers_producer_init"
    )

    case init_producer(realm_name) do
      {:ok, state} ->
        {:ok, state, 60_000}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call(
        {:publish, exchange, routing_key, payload, opts},
        _from,
        {conn, chan, realm_name}
      ) do
    reply = @adapter.publish(chan, exchange, routing_key, payload, opts)

    {:reply, reply, {conn, chan, realm_name}, 60_000}
  end

  @impl GenServer
  def handle_call({:declare_exchange, exchange}, _from, {conn, chan, realm_name}) do
    reply = @adapter.declare_exchange(chan, exchange, type: :direct, durable: true)

    {:reply, reply, {conn, chan, realm_name}, 60_000}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, _pid, reason}, {conn, _channel, realm_name}) do
    Logger.warning("RabbitMQ connection lost: #{inspect(reason)}. Trying to reconnect...",
      tag: "events_producer_conn_lost"
    )

    :ok = Connection.close(conn)

    case init_producer(realm_name) do
      {:ok, new_state} ->
        {:noreply, new_state, 60_000}

      {:error, _reason} ->
        schedule_connect()
        {:noreply, {:not_connected, realm_name}}
    end
  end

  @impl GenServer
  def handle_info(:timeout, {conn, channel, _realm_name}) do
    Logger.warning("No activity in the last 60 seconds, shutting down...",
      tag: "events_producer_timeout"
    )

    :ok = Channel.close(channel)
    :ok = Connection.close(conn)

    {:stop, :normal, :timeout}
  end

  defp init_producer(realm_name) do
    vhost = vhost_name(realm_name)

    trigger_producer_conf =
      Config.amqp_triggers_producer_options!()
      |> Keyword.put(:virtual_host, vhost)

    with {:ok, connection} <- Connection.open(trigger_producer_conf) do
      case Channel.open(connection) do
        {:ok, %Channel{pid: channel_pid} = channel} ->
          Process.monitor(channel_pid)
          {:ok, {connection, channel, realm_name}}

        {:error, reason} ->
          Logger.warning("Connection not available for realm #{realm_name}, aborting...",
            tag: "event_producer_channel_checkout_fail"
          )

          {:error, reason}
      end
    end
  end

  defp schedule_connect() do
    Logger.warning("Retrying connection in #{@connection_backoff} ms")
    Process.send_after(self(), :init, @connection_backoff)
  end

  def vhost_name(realm_name) do
    astarte_instance = Astarte.DataAccess.Config.astarte_instance_id!()
    "#{astarte_instance}_#{realm_name}"
  end
end
