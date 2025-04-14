#
# This file is part of Astarte.
#
# Copyright 2022 - 2025 SECO Mind Srl
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
    use TypedStruct

    alias Astarte.Core.Triggers.Policy
    alias AMQP.Channel

    typedstruct do
      field :channel, Channel.t()
      field :monitor, reference()
      field :realm_name, String.t()
      field :policy, Policy.t()
    end
  end

  use GenServer
  require Logger
  alias Astarte.TriggerEngine.AMQPConsumer.AMQPMessageConsumer.Impl
  alias Astarte.TriggerEngine.Policy

  @reconnect_interval 1_000

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
  def handle_continue(:connect, state), do: connect(state)

  @impl true
  def handle_info(:connect, state), do: connect(state)

  @impl true
  def handle_info(
        {:DOWN, monitor, :process, chan_pid, _reason},
        %{monitor: monitor, channel: %{pid: chan_pid}} = state
      ) do
    connect(state)
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
        "consumer for #{realm_name}, #{policy.name} received message, payload: #{inspect(payload)}, meta: #{inspect(meta)}",
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

  defp connect(state) do
    %{channel: channel, monitor: monitor} = do_connect(state)
    new_state = %{state | channel: channel, monitor: monitor}
    {:noreply, new_state}
  end

  @spec do_connect(State.t()) ::
          %{channel: AMQP.Channel.t(), monitor: reference()} | %{channel: nil, monitor: nil}
  defp do_connect(state) do
    case Impl.connect(state.realm_name, state.policy) do
      {:ok, channel, monitor} ->
        %{channel: channel, monitor: monitor}

      {:error, _reason} ->
        schedule_connect()
        %{channel: nil, monitor: nil}
    end
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
