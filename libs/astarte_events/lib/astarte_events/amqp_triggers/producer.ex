#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Astarte.Events.AMQPTriggers.Producer do
  @moduledoc """
  Handles connection and publishing messages to an AMQP broker.
  """
  use GenServer, restart: :transient
  require Logger

  alias AMQP.{Channel, Connection}
  alias Astarte.Events.Config
  alias ExRabbitPool.RabbitMQ

  @connection_backoff 10_000

  def start_link(args) do
    realm_name = Keyword.fetch!(args, :realm)
    server = Keyword.fetch!(args, :server)

    Logger.info("AMQPTriggers producer start link for realm #{realm_name}",
      tag: "amqp_triggers_producer_start_link"
    )

    GenServer.start_link(__MODULE__, args, name: server)
  end

  def publish(server, exchange, routing_key, payload, opts) do
    GenServer.call(server, {:publish, exchange, routing_key, payload, opts}, 60_000)
  end

  def declare_exchange(server, exchange) when is_binary(exchange) do
    GenServer.call(server, {:declare_exchange, exchange}, 60_000)
  end

  @impl true
  def init(opts) do
    realm_name = Keyword.fetch!(opts, :realm)
    wait_start = Keyword.get(opts, :wait_start, false)

    Logger.info("AMQPTriggers producer init for realm #{realm_name}.",
      tag: "amqp_triggers_producer_init"
    )

    if wait_start do
      {:ok, {:wait_start, realm_name}, 60_000}
    else
      case init_producer(realm_name) do
        {:ok, state} -> {:ok, state, 60_000}
        {:error, reason} -> {:stop, reason}
      end
    end
  end

  def handle_call(:start, _from, {:wait_start, realm_name}) do
    case init_producer(realm_name) do
      {:ok, state} -> {:reply, :ok, state, 60_000}
      {:error, reason} -> {:stop, reason, {:error, reason}, {:wait_start, realm_name}}
    end
  end

  @impl true
  def handle_call({:publish, exchange, routing_key, payload, opts}, _from, {conn, chan, realm}) do
    reply = RabbitMQ.publish(chan, exchange, routing_key, payload, opts)
    {:reply, reply, {conn, chan, realm}, 60_000}
  end

  @impl true
  def handle_call({:declare_exchange, exchange}, _from, {conn, chan, realm}) do
    reply = RabbitMQ.declare_exchange(chan, exchange, type: :direct, durable: true)
    {:reply, reply, {conn, chan, realm}, 60_000}
  end

  @impl true
  def handle_info({:DOWN, _, :process, _pid, reason}, {conn, _chan, realm}) do
    Logger.warning("RabbitMQ connection lost: #{inspect(reason)}. Trying to reconnect...",
      tag: "amqp_triggers_producer_conn_lost"
    )

    :ok = Connection.close(conn)

    case init_producer(realm) do
      {:ok, new_state} ->
        {:noreply, new_state, 60_000}

      {:error, _} ->
        schedule_connect()
        {:noreply, {:not_connected, realm}}
    end
  end

  @impl true
  def handle_info(:timeout, {conn, channel, _realm}) do
    Logger.warning("No activity in the last 60 seconds, shutting down...",
      tag: "amqp_triggers_producer_timeout"
    )

    :ok = Channel.close(channel)
    :ok = Connection.close(conn)
    {:stop, :normal, :timeout}
  end

  defp init_producer(realm_name) do
    amqp_opts =
      Config.amqp_options!()
      |> Keyword.put(:virtual_host, vhost_name(realm_name))

    with {:ok, connection} <- Connection.open(amqp_opts) do
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

  defp schedule_connect do
    Logger.warning("Retrying connection in #{@connection_backoff} ms")
    Process.send_after(self(), :init, @connection_backoff)
  end

  def vhost_name(realm_name) do
    astarte_instance = Astarte.DataAccess.Config.astarte_instance_id!()
    "#{astarte_instance}_#{realm_name}"
  end
end
