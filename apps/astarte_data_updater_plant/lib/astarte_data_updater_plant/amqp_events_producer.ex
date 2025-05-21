#
# This file is part of Astarte.
#
# Copyright 2017-2020 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlant.AMQPEventsProducer do
  require Logger
  use GenServer

  alias Astarte.DataUpdaterPlant.Config
  alias AMQP.Channel

  @connection_backoff 10000
  @adapter Config.amqp_adapter!()

  # API

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def publish(exchange, routing_key, payload, opts) do
    # Use a longer timeout to allow RabbitMQ to process requests even if loaded
    GenServer.call(__MODULE__, {:publish, exchange, routing_key, payload, opts}, 60_000)
  end

  def declare_exchange(exchange) do
    # Use a longer timeout to allow RabbitMQ to process requests even if loaded
    GenServer.call(__MODULE__, {:declare_exchange, exchange}, 60_000)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    case init_producer() do
      {:ok, chan} ->
        {:ok, chan}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:publish, exchange, routing_key, payload, opts}, _from, chan) do
    reply = @adapter.publish(chan, exchange, routing_key, payload, opts)

    {:reply, reply, chan}
  end

  def handle_call({:declare_exchange, exchange}, _from, chan) do
    # TODO: we need to decide who is responsible of deleting the exchange once it is
    # no longer needed
    reply = @adapter.declare_exchange(chan, exchange, type: :direct, durable: true)

    {:reply, reply, chan}
  end

  @impl true
  def handle_info({:DOWN, _, :process, _pid, reason}, _state) do
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
    conn = ExRabbitPool.get_connection_worker(:dup_events_producer_pool)

    with {:ok, channel} <- checkout_channel(conn),
         :ok <- declare_default_events_exchange(channel, conn) do
      %Channel{pid: channel_pid} = channel
      _ref = Process.monitor(channel_pid)

      _ =
        Logger.debug("AMQPEventsProducer initialized",
          tag: "event_producer_init_ok"
        )

      {:ok, channel}
    end
  end

  defp checkout_channel(conn) do
    with {:error, reason} <- ExRabbitPool.checkout_channel(conn) do
      _ =
        Logger.warning(
          "Failed to check out channel for producer: #{inspect(reason)}",
          tag: "event_producer_channel_checkout_fail"
        )

      {:error, :event_producer_channel_checkout_fail}
    end
  end

  defp declare_default_events_exchange(channel, conn) do
    with {:error, reason} <-
           @adapter.declare_exchange(channel, Config.events_exchange_name!(),
             type: :direct,
             durable: true
           ) do
      Logger.warning(
        "Error declaring AMQPEventsProducer default events exchange: #{inspect(reason)}",
        tag: "event_producer_init_fail"
      )

      # Something went wrong, let's put the channel back where it belongs
      _ = ExRabbitPool.checkin_channel(conn, channel)
      {:error, :event_producer_init_fail}
    end
  end

  defp schedule_connect() do
    _ = Logger.warning("Retrying connection in #{@connection_backoff} ms")
    Process.send_after(@connection_backoff, self(), :init)
  end
end
