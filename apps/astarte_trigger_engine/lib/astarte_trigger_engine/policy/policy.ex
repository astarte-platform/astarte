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

defmodule Astarte.TriggerEngine.Policy do
  use GenServer
  require Logger

  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.Policy
  alias Astarte.TriggerEngine.Config
  # TODO use the ExRabbitPool.RabbitMQ adapter when it will have a `nack` function
  alias AMQP.Basic

  @consumer Config.events_consumer!()

  # API
  def start_link(args \\ []) do
    realm_name = Keyword.fetch!(args, :realm_name)
    policy = Keyword.fetch!(args, :policy)

    GenServer.start_link(__MODULE__, args, name: via_tuple(realm_name, policy.name))
  end

  def handle_event(pid, channel, payload, meta) do
    _ =
      Logger.debug(
        "policy process #{inspect(pid)} got event, payload: #{inspect(payload)},  meta: #{inspect(meta)}",
        tag: "policy_handle_event"
      )

    GenServer.cast(pid, {:handle_event, channel, payload, meta})
  end

  # Server callbacks

  def init(args) do
    policy = Keyword.get(args, :policy)
    state = %{policy: policy, retry_map: %{}}
    {:ok, state}
  end

  def handle_cast(
        {:handle_event, chan, payload, meta},
        %{policy: policy, retry_map: retry_map} = _state
      ) do
    {headers, _other_meta} = Map.pop(meta, :headers, [])
    headers_map = amqp_headers_to_map(headers)

    verify_event_consumed = @consumer.consume(payload, headers_map)
    retry_map = Map.update(retry_map, meta.message_id, 1, fn value -> value + 1 end)

    _ =
      Logger.debug(
        "Handling event #{meta.message_id}, this is the #{Map.get(retry_map, meta.message_id)}-th time"
      )

    case verify_event_consumed do
      # All was ok
      :ok ->
        Basic.ack(chan, meta.delivery_tag)
        retry_map = Map.delete(retry_map, meta.message_id)
        {:noreply, %{policy: policy, retry_map: retry_map}}

      {:http_error, status_code} ->
        maybe_requeue_message(chan, meta, status_code, policy, retry_map)

      {:error, :trigger_not_found} ->
        discard_message(chan, meta, policy, retry_map)
    end
  end

  defp maybe_requeue_message(chan, meta, status_code, policy, retry_map) do
    if should_requeue_message?(meta.message_id, status_code, policy, retry_map) do
      requeue_message(chan, meta, policy, retry_map)
    else
      discard_message(chan, meta, policy, retry_map)
    end
  end

  defp requeue_message(chan, meta, policy, retry_map) do
    Basic.nack(chan, meta.delivery_tag, requeue: true)

    {:noreply, %{policy: policy, retry_map: retry_map}}
  end

  defp discard_message(chan, meta, policy, retry_map) do
    Basic.nack(chan, meta.delivery_tag, requeue: false)

    retry_map = Map.delete(retry_map, meta.message_id)
    {:noreply, %{policy: policy, retry_map: retry_map}}
  end

  defp should_requeue_message?(
         event_id,
         error_number,
         %Policy{error_handlers: handlers, retry_times: retry_times},
         retry_map
       ) do
    handler = Enum.find(handlers, fn handler -> Handler.includes?(handler, error_number) end)

    retry? =
      handler != nil and not Handler.discards?(handler) and retry_times != nil and
        Map.get(retry_map, event_id) < retry_times

    _ = Logger.debug("Event #{event_id} was processed; scheduled for retry? #{retry?}")
    retry?
  end

  defp amqp_headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {key, _type, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp via_tuple(realm_name, policy_name) do
    {:via, Registry, {Registry.PolicyRegistry, {realm_name, policy_name}}}
  end
end
