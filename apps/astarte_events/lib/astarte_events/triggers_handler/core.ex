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

defmodule Astarte.Events.TriggersHandler.Core do
  @moduledoc """
  Core module for handling triggers in Astarte Events.
  """
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Events.AMQPEvents
  alias Astarte.Events.AMQPTriggers

  import Bitwise, only: [<<<: 2]

  require Logger

  @max_backoff_exponent 8
  @max_rand trunc(:math.pow(2, 32) - 1)

  def register_target(_realm_name, %AMQPTriggerTarget{exchange: nil} = _target) do
    # Default exchange, no need to declare it
    :ok
  end

  def register_target(realm_name, %AMQPTriggerTarget{exchange: exchange} = _target) do
    AMQPTriggers.declare_exchange(realm_name, exchange)
  end

  def dispatch_event(
        %SimpleEvent{} = simple_event,
        %AMQPTriggerTarget{
          exchange: target_exchange,
          routing_key: routing_key,
          static_headers: static_headers,
          message_expiration_ms: message_expiration_ms,
          message_priority: message_priority,
          message_persistent: message_persistent
        },
        policy_name
      ) do
    {event_type, _event_struct} = simple_event.event

    simple_trigger_id_str =
      simple_event.simple_trigger_id
      |> UUID.binary_to_string!()

    parent_trigger_id_str =
      simple_event.parent_trigger_id
      |> UUID.binary_to_string!()

    headers = [
      {"x_astarte_realm", simple_event.realm},
      {"x_astarte_device_id", simple_event.device_id},
      {"x_astarte_simple_trigger_id", simple_trigger_id_str},
      {"x_astarte_parent_trigger_id", parent_trigger_id_str},
      {"x_astarte_event_type", to_string(event_type)}
      | Enum.to_list(static_headers)
    ]

    {routing_key, headers} =
      update_if_has_policy(
        routing_key,
        headers,
        simple_event.realm,
        policy_name
      )

    opts_with_nil = [
      expiration: message_expiration_ms && to_string(message_expiration_ms),
      priority: message_priority,
      persistent: message_persistent,
      message_id:
        generate_message_id(simple_event.realm, simple_event.device_id, simple_event.timestamp)
    ]

    opts = Enum.filter(opts_with_nil, fn {_k, v} -> v != nil end)

    payload = SimpleEvent.encode(simple_event)

    result =
      wait_ok_publish(
        simple_event.realm,
        target_exchange,
        routing_key,
        payload,
        [{:headers, headers} | opts]
      )

    Logger.debug("headers: #{inspect(headers)}, routing key: #{inspect(routing_key)}")

    result
  end

  defp update_if_has_policy(
         "trigger_engine",
         headers,
         realm,
         policy_name
       ) do
    policy_name = policy_name || "@default"

    headers = [
      {"x_astarte_trigger_policy", policy_name}
      | headers
    ]

    routing_key = generate_routing_key(realm, policy_name)

    {routing_key, headers}
  end

  defp update_if_has_policy(
         routing_key,
         headers,
         _realm,
         _policy_name
       ) do
    {routing_key, headers}
  end

  defp generate_message_id(realm, device_id, timestamp) do
    realm_trunc = String.slice(realm, 0..63)
    device_id_trunc = String.slice(device_id, 0..15)
    timestamp_hex_str = Integer.to_string(timestamp, 16)
    rnd = Enum.random(0..@max_rand) |> Integer.to_string(16)

    "#{realm_trunc}-#{device_id_trunc}-#{timestamp_hex_str}-#{rnd}"
  end

  defp wait_ok_publish(realm, exchange, routing_key, payload, opts) do
    publish(realm, exchange, routing_key, payload, opts)
    |> wait_backoff_and_publish(realm, 1, nil, routing_key, payload, opts)
  end

  defp wait_backoff_and_publish(
         :ok,
         _realm,
         _retry,
         _exchange,
         _routing_key,
         _payload,
         _opts
       ) do
    :ok
  end

  defp wait_backoff_and_publish(
         {:error, reason},
         realm,
         retry,
         exchange,
         routing_key,
         payload,
         opts
       ) do
    Logger.warning(
      "Failed publish on events exchange with #{routing_key}. Reason: #{inspect(reason)}"
    )

    retry
    |> compute_backoff_time()
    |> :timer.sleep()

    next_retry =
      if retry <= @max_backoff_exponent do
        retry + 1
      else
        retry
      end

    publish(realm, exchange, routing_key, payload, opts)
    |> wait_backoff_and_publish(realm, next_retry, exchange, routing_key, payload, opts)
  end

  defp compute_backoff_time(current_attempt) do
    minimum_duration = (1 <<< current_attempt) * 1000
    minimum_duration + round(minimum_duration * 0.25 * :rand.uniform())
  end

  defp generate_routing_key(realm, policy) do
    "#{realm}_#{policy}"
  end

  defp publish(_realm, nil, routing_key, payload, opts) do
    AMQPEvents.publish(routing_key, payload, opts)
  end

  defp publish(realm, exchange, routing_key, payload, opts) do
    AMQPTriggers.publish(realm, exchange, routing_key, payload, opts)
  end
end
