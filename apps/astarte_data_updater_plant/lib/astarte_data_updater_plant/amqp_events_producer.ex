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
  alias AMQP.Exchange
  alias Astarte.DataUpdaterPlant.Config

  # API

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def publish(exchange, routing_key, payload, opts) do
    GenServer.call(__MODULE__, {:publish, exchange, routing_key, payload, opts})
  end

  def declare_exchange(exchange) do
    GenServer.call(__MODULE__, {:declare_exchange, exchange})
  end

  # Server callbacks

  def init(_args) do
    ExRabbitPool.with_channel(:producers_pool, fn
      {:ok, channel} ->
        case Exchange.declare(channel, Config.events_exchange_name!(), :direct, durable: true) do
          :ok ->
            {:ok, {}}

          {:error, reason} ->
            Logger.warn("RabbitMQ exchange declaration error: #{inspect(reason)}",
              tag: "events_producer_exchange_err"
            )

            {:stop, :connection_failed}
        end

      {:error, reason} ->
        Logger.warn("RabbitMQ Connection error: #{inspect(reason)}",
          tag: "events_producer_conn_err"
        )

        {:stop, :connection_failed}
    end)
  end

  def handle_call(
        {:publish, exchange, routing_key, payload, opts},
        _from,
        state
      ) do
    ExRabbitPool.with_channel(:producers_pool, fn {:ok, channel} ->
      reply = Basic.publish(channel, exchange, routing_key, payload, opts)
      {:reply, reply, state}
    end)
  end

  def handle_call({:declare_exchange, exchange}, _from, state) do
    # TODO: we need to decide who is responsible of deleting the exchange once it is
    # no longer needed
    ExRabbitPool.with_channel(:producers_pool, fn {:ok, channel} ->
      reply = Exchange.declare(channel, exchange, :direct, durable: true)
      {:reply, reply, state}
    end)
  end
end
