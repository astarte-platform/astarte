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

  alias AMQP.Basic
  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Exchange
  alias Astarte.DataUpdaterPlant.Config

  @connection_backoff 10000

  # API

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def publish(exchange, routing_key, payload, opts) do
    GenServer.call(__MODULE__, {:publish, exchange, routing_key, payload, opts})
  end

  # Server callbacks

  def init(_args) do
    rabbitmq_connect(false)
  end

  def terminate(_reason, %Channel{conn: conn} = chan) do
    Channel.close(chan)
    Connection.close(conn)
  end

  def handle_call({:publish, exchange, routing_key, payload, opts}, _from, chan) do
    reply = Basic.publish(chan, exchange, routing_key, payload, opts)

    {:reply, reply, chan}
  end

  def handle_info(:try_to_connect, _state) do
    {:ok, new_state} = rabbitmq_connect()
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _state) do
    Logger.warn("RabbitMQ connection lost: #{inspect(reason)}. Trying to reconnect...",
      tag: "events_producer_conn_lost"
    )

    {:ok, new_state} = rabbitmq_connect()
    {:noreply, new_state}
  end

  defp rabbitmq_connect(retry \\ true) do
    with {:ok, conn} <- Connection.open(Config.amqp_producer_options!()),
         {:ok, chan} <- Channel.open(conn),
         :ok <- Exchange.declare(chan, Config.events_exchange_name!(), :direct, durable: true),
         # Get notifications when the chan or connection goes down
         Process.monitor(chan.pid) do
      {:ok, chan}
    else
      {:error, reason} ->
        Logger.warn("RabbitMQ Connection error: #{inspect(reason)}",
          tag: "events_producer_conn_err"
        )

        maybe_retry(retry)

      :error ->
        Logger.warn("Unknown RabbitMQ connection error", tag: "events_producer_conn_err")
        maybe_retry(retry)
    end
  end

  defp maybe_retry(retry) do
    if retry do
      Logger.warn("Retrying connection in #{@connection_backoff} ms")
      :erlang.send_after(@connection_backoff, :erlang.self(), :try_to_connect)
      {:ok, :not_connected}
    else
      {:stop, :connection_failed}
    end
  end
end
