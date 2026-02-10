#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind srl
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

defmodule Astarte.Events.Test.AmqpTriggers.Consumer do
  @moduledoc """
  A simple AMQP Consumer for testing purposes.
  It connects to the AMQP broker, declares the necessary exchange and queue.
  """
  defmodule State do
    @moduledoc """
    State struct for the AMQP Consumer GenServer
    """
    @type t :: %__MODULE__{
            channel: AMQP.Channel.t() | nil,
            realm_name: String.t(),
            routing_key: String.t(),
            message_handler: (binary(), map() -> :ok | :error | {:error, term()}),
            ready_pid: pid() | nil
          }

    defstruct [:channel, :realm_name, :routing_key, :message_handler, :ready_pid]
  end

  use GenServer

  alias AMQP.Basic
  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Exchange
  alias AMQP.Queue
  alias Astarte.Events.AMQP.Vhost
  alias Astarte.Events.Config

  require Logger

  def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg)

  @impl true
  def init(opts) do
    wait_start = Keyword.get(opts, :wait_start, false)

    realm_name = Keyword.fetch!(opts, :realm_name)
    routing_key = Keyword.fetch!(opts, :routing_key)
    message_handler = Keyword.fetch!(opts, :message_handler)
    ready_pid = Keyword.fetch!(opts, :ready_pid)

    state = %State{
      realm_name: realm_name,
      routing_key: routing_key,
      message_handler: message_handler,
      ready_pid: ready_pid
    }

    if wait_start do
      {:ok, state}
    else
      {:ok, state, {:continue, :connect}}
    end
  end

  def stop(server) do
    GenServer.call(server, :stop)
  end

  @impl true
  def handle_call(:start, _from, state) do
    {:reply, :ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    Logger.info("Stopping consumer for routing key #{inspect(state.routing_key)}")
    Channel.close(state.channel)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_continue(:connect, state), do: connect(state)

  # Confirmation sent by the broker after registering this process as a consumer
  @impl true
  def handle_info({:basic_consume_ok, _consumer_tag}, state) do
    Logger.debug("AMQP consumer successfully registered")

    {:noreply, state}
  end

  # This is sent for each message consumed, where `payload` contains the message
  # content and `meta` contains all the metadata set when sending with
  # Basic.publish or additional info set by the broker;
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    case state.message_handler.(payload, meta) do
      :ok -> Basic.ack(state.channel, meta.delivery_tag)
      :error -> Basic.nack(state.channel, meta.delivery_tag)
      {:error, _reason} -> Basic.nack(state.channel, meta.delivery_tag)
    end

    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  @impl true
  def handle_info({:basic_cancel, _}, state) do
    Logger.error("AMQP consumer was cancelled by the broker")

    {:stop, :shutdown, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  @impl true
  def handle_info({:basic_cancel_ok, _}, state) do
    Logger.info("AMQP consumer was cancelled by the broker")

    {:stop, :normal, state}
  end

  defp connect(state) do
    state = do_connect(state)
    {:noreply, state}
  end

  @spec do_connect(State.t()) :: State.t()
  defp do_connect(state) do
    %{realm_name: realm_name, routing_key: routing_key} = state
    exchange_suffix = "events"
    exchange_name = "astarte_events_#{realm_name}_#{exchange_suffix}"
    queue_name = exchange_name <> routing_key

    amqp_consumer_opts =
      Config.amqp_options!()
      |> Keyword.put(:virtual_host, Vhost.vhost_name(realm_name))

    with {:ok, connection} <- Connection.open(amqp_consumer_opts),
         {:ok, channel} <- Channel.open(connection),
         :ok <- Basic.qos(channel, prefetch_count: 300),
         :ok <- Exchange.declare(channel, exchange_name, :direct, durable: true),
         {:ok, _} <- Queue.declare(channel, queue_name, durable: true),
         :ok <- Queue.bind(channel, queue_name, exchange_name, routing_key: routing_key),
         {:ok, _} <- Basic.consume(channel, queue_name) do
      if state.ready_pid do
        send(state.ready_pid, :consumer_ready)
      end

      "Queue #{queue_name} on exchange #{exchange_name} declared, bound with routing key #{routing_key}"
      |> Logger.debug()

      %{state | channel: channel}
    end
  end
end
