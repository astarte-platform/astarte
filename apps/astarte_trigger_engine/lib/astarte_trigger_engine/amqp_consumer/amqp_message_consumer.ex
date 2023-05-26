#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.TriggerEngine.AMQPConsumer.AMQPMessageConsumer do
  defmodule State do
    defstruct [
      :channel,
      :monitor,
      :realm_name,
      :policy
    ]
  end

  use GenServer
  require Logger
  alias Astarte.TriggerEngine.Policy
  alias Astarte.TriggerEngine.Config
  alias Astarte.Core.Triggers.Policy, as: PolicyStruct

  @reconnect_interval 1_000
  @adapter Config.amqp_adapter!()

  def start_link(args \\ []) do
    realm_name = Keyword.fetch!(args, :realm_name)
    policy = Keyword.fetch!(args, :policy)

    case GenServer.start_link(__MODULE__, args, name: via_tuple(realm_name, policy.name)) do
      {:ok, pid} ->
        Logger.info(
          "Started AMQPMessageConsumer for policy #{policy.name} of realm #{realm_name}"
        )

        {:ok, pid}

      {:error, {:already_started, pid}} ->
        # Already started, we don't care
        {:ok, pid}
    end
  end

  @impl true
  def init(opts) do
    realm_name = Keyword.fetch!(opts, :realm_name)
    policy = Keyword.fetch!(opts, :policy)

    state = %State{
      realm_name: realm_name,
      policy: policy
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state), do: do_connect(state)

  @impl true
  def handle_info(:connect, state), do: do_connect(state)

  @impl true
  def handle_info(
        {:DOWN, monitor, :process, chan_pid, _reason},
        %{monitor: monitor, channel: %{pid: chan_pid}} = state
      ) do
    do_connect(state)
  end

  # Confirmation sent by the broker after registering this process as a consumer
  @impl true
  def handle_info(
        {:basic_consume_ok, _consumer_tag},
        %{realm_name: realm_name, policy: policy} = state
      ) do
    _ =
      Logger.debug(
        "consumer for #{realm_name}, #{policy.name} successfully registered",
        tag: "basic_consume_ok"
      )

    {:noreply, state}
  end

  # This is sent for each message consumed, where `payload` contains the message
  # content and `meta` contains all the metadata set when sending with
  # Basic.publish or additional info set by the broker;
  @impl true
  def handle_info(
        {:basic_deliver, payload, meta},
        %{realm_name: realm_name, policy: policy, channel: chan} = state
      ) do
    _ =
      Logger.debug(
        "consumer for #{realm_name}, #{policy.name} received message, payload: #{inspect(payload)}, meta: #{
          inspect(meta)
        }",
        tag: "message_received"
      )

    get_policy_process(realm_name, policy)
    |> Policy.handle_event(chan, payload, meta)

    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  @impl true
  def handle_info({:basic_cancel, _}, %{realm_name: realm_name, policy: policy} = state) do
    _ =
      Logger.error("consumer for #{realm_name}, #{policy.name} was cancelled by the broker",
        tag: "basic_cancel"
      )

    {:stop, :shutdown, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  @impl true
  def handle_info({:basic_cancel_ok, _}, %{realm_name: realm_name, policy: policy} = state) do
    _ =
      Logger.info("consumer for #{realm_name}, #{policy.name} was cancelled by the broker",
        tag: "basic_cancel_ok"
      )

    {:stop, :normal, state}
  end

  defp schedule_connect() do
    Process.send_after(self(), :connect, @reconnect_interval)
  end

  # Gets a connection worker out of the connection pool, if there is one available
  # takes a channel out of it channel pool, if there is one available
  # subscribe itself as a consumer process.
  defp do_connect(state) do
    conn = ExRabbitPool.get_connection_worker(:events_consumer_pool)

    case ExRabbitPool.checkout_channel(conn) do
      {:ok, channel} ->
        try_to_connect(channel, state)

      {:error, _reason} ->
        schedule_connect()
        {:noreply, state}
    end
  end

  # When successfully checks out a channel, sets up exchange and queue, subscribe itself as a consumer
  # process and monitors it handle crashes and reconnections
  defp try_to_connect(channel, state) do
    %{pid: channel_pid} = channel
    %{policy: policy, realm_name: realm_name} = state

    exchange_name = Config.events_exchange_name!()
    queue_name = generate_queue_name(realm_name, policy.name)
    routing_key = generate_routing_key(realm_name, policy.name)

    with :ok <- @adapter.qos(channel, prefetch_count: prefetch_count_or_default(policy)),
         :ok <- @adapter.declare_exchange(channel, exchange_name, type: :direct, durable: true),
         {:ok, _queue} <- @adapter.declare_queue(channel, queue_name, durable: true),
         :ok <-
           @adapter.queue_bind(
             channel,
             queue_name,
             exchange_name,
             routing_key: routing_key,
             arguments: [{"x-queue-mode", :longstr, "lazy"} | generate_policy_x_args(policy)]
           ),
         {:ok, _consumer_tag} <- @adapter.consume(channel, queue_name, self()) do
      ref = Process.monitor(channel_pid)

      _ =
        Logger.debug(
          "Queue #{queue_name} on exchange #{exchange_name} declared, bound with routing key #{
            routing_key
          }",
          tag: "queue_bound"
        )

      {:noreply, %{state | channel: channel, monitor: ref}}
    else
      {:error, _reason} ->
        schedule_connect()
        {:noreply, %{state | channel: nil, monitor: nil}}
    end
  end

  # Protobuf3 encodes missing int field as 0
  defp prefetch_count_or_default(%PolicyStruct{prefetch_count: 0}),
    do: Config.amqp_consumer_prefetch_count!()

  defp prefetch_count_or_default(%PolicyStruct{prefetch_count: prefetch_count}),
    do: prefetch_count

  defp generate_policy_x_args(%PolicyStruct{
         maximum_capacity: maximum_capacity,
         event_ttl: event_ttl
       }) do
    []
    |> put_x_arg_if(maximum_capacity != nil, {"x-max-length", :signedint, maximum_capacity})
    |> put_x_arg_if(event_ttl != nil, {"x-message-ttl", :signedint, event_ttl})
  end

  defp put_x_arg_if(list, true, x_arg), do: [x_arg | list]
  defp put_x_arg_if(list, false, _x_arg), do: list

  defp generate_queue_name(realm, policy) do
    "#{realm}_#{policy}_queue"
  end

  defp generate_routing_key(realm, policy) do
    "#{realm}_#{policy}"
  end

  defp get_policy_process(realm_name, policy) do
    # Link the policy process so we crash if it crashes; in this way unacked messages will be requeued
    case Policy.start_link(realm_name: realm_name, policy: policy) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        # Already started, we don't care
        pid
    end
  end

  defp via_tuple(realm_name, policy_name) do
    {:via, Registry, {Registry.AMQPConsumerRegistry, {realm_name, policy_name}}}
  end
end
