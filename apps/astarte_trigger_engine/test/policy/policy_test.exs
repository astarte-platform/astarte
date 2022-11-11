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

defmodule Astarte.TriggerEngine.PolicyTest do
  use ExUnit.Case
  require Logger
  import Mox
  alias Astarte.TriggerEngine.Config
  alias AMQP.Basic
  alias Astarte.TriggerEngine.Policy, as: PolicyProcess
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange

  @realm_name "autotestrealm"
  @payload "some_payload"
  @max_retry_times 10
  @message_id "message_id"
  @headers [
    one: "header",
    another: "different header",
    number: 42,
    x_astarte_realm: @realm_name
  ]

  @retry_all_policy %Policy{
    name: "retry_all",
    retry_times: @max_retry_times,
    maximum_capacity: 100,
    error_handlers: [
      %Handler{on: %ErrorKeyword{keyword: "any_error"}, strategy: "retry"}
    ]
  }

  @retry_all_policy_2 %Policy{
    name: "retry_all_2",
    retry_times: @max_retry_times,
    maximum_capacity: 100,
    error_handlers: [
      %Handler{on: %ErrorKeyword{keyword: "any_error"}, strategy: "retry"}
    ]
  }

  @discard_all_policy %Policy{
    name: "discard_all",
    maximum_capacity: 100,
    error_handlers: [
      %Handler{on: %ErrorKeyword{keyword: "any_error"}, strategy: "discard"}
    ]
  }

  @mixed_policy %Policy{
    name: "mixed",
    maximum_capacity: 100,
    retry_times: @max_retry_times,
    error_handlers: [
      %Handler{on: %ErrorKeyword{keyword: "server_error"}, strategy: "discard"},
      %Handler{on: %ErrorRange{error_codes: [401, 402, 403, 404]}, strategy: "retry"}
    ]
  }

  test "delivered message is not retried" do
    routing_key = generate_routing_key(@realm_name, @retry_all_policy.name)
    headers_list = [x_astarte_trigger_policy: @retry_all_policy.name] ++ @headers

    mock =
      MockEventsConsumer
      |> expect(:consume, 1, fn payload, headers ->
        assert payload == @payload
        assert headers == headers_list
        :ok
      end)
      |> expect(:consume, 0, fn _, _ ->
        :ok
      end)

    Mox.allow(mock, self(), get_policy_process(@realm_name, @retry_all_policy))

    assert :ok =
             ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
               produce_event(chan, routing_key, @payload, @headers, @message_id)
             end)

    registered_policies =
      Registry.select(Registry.PolicyRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

    assert {@realm_name, @retry_all_policy.name} in registered_policies
  end

  test "successfully retry message with retry strategy" do
    routing_key = generate_routing_key(@realm_name, @retry_all_policy.name)

    headers_list = [x_astarte_trigger_policy: @retry_all_policy.name] ++ @headers

    mock =
      MockEventsConsumer
      |> expect(:consume, 1, fn payload, headers ->
        assert payload == @payload
        assert headers == headers_list
        {:http_error, 418}
      end)
      |> expect(:consume, 1, fn payload, headers ->
        assert payload == @payload
        assert headers == headers_list
        :ok
      end)

    Mox.allow(mock, self(), get_policy_process(@realm_name, @retry_all_policy))

    assert :ok =
             ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
               produce_event(chan, routing_key, @payload, headers_list, @message_id)
             end)

    registered_policies =
      Registry.select(Registry.PolicyRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

    assert {@realm_name, @retry_all_policy.name} in registered_policies
  end

  test "discard message with retry strategy policy when delivery fails >= retry_times" do
    routing_key = generate_routing_key(@realm_name, @retry_all_policy_2.name)

    headers_list = [x_astarte_trigger_policy: @retry_all_policy_2.name] ++ @headers

    mock =
      MockEventsConsumer
      |> expect(:consume, @max_retry_times, fn payload, headers ->
        assert payload == @payload
        assert headers == headers_list
        {:http_error, 418}
      end)

    Mox.allow(mock, self(), get_policy_process(@realm_name, @retry_all_policy_2))

    assert :ok =
             ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
               produce_event(chan, routing_key, @payload, headers_list, @message_id)
             end)

    registered_policies =
      Registry.select(Registry.PolicyRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

    assert {@realm_name, @retry_all_policy_2.name} in registered_policies
  end

  test "discard message with discard strategy when delivery fails" do
    routing_key = generate_routing_key(@realm_name, @discard_all_policy.name)

    headers_list = [x_astarte_trigger_policy: @discard_all_policy.name] ++ @headers

    mock =
      MockEventsConsumer
      |> expect(:consume, 1, fn payload, headers ->
        assert payload == @payload
        assert headers == headers_list
        {:http_error, 500}
      end)

    Mox.allow(mock, self(), get_policy_process(@realm_name, @discard_all_policy))

    assert :ok =
             ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
               produce_event(chan, routing_key, @payload, headers_list, @message_id)
             end)

    registered_policies =
      Registry.select(Registry.PolicyRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

    assert {@realm_name, @discard_all_policy.name} in registered_policies
  end

  test "mixed policy retries correctly" do
    routing_key = generate_routing_key(@realm_name, @mixed_policy.name)

    headers_list = [x_astarte_trigger_policy: @mixed_policy.name] ++ @headers

    mock =
      MockEventsConsumer
      |> expect(:consume, 10, fn payload, headers ->
        assert payload == @payload
        assert headers == headers_list
        {:http_error, 404}
      end)
      |> expect(:consume, 1, fn payload, headers ->
        assert payload == @payload
        assert headers == headers_list
        {:http_error, 500}
      end)
      |> expect(:consume, 1, fn payload, headers ->
        assert payload == @payload
        assert headers == headers_list
        :ok
      end)

    Mox.allow(mock, self(), get_policy_process(@realm_name, @mixed_policy))

    assert :ok =
             ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
               produce_event(chan, routing_key, @payload, headers_list, "message1")
             end)

    assert :ok =
             ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
               produce_event(chan, routing_key, @payload, headers_list, "message2")
             end)

    assert :ok =
             ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
               produce_event(chan, routing_key, @payload, headers_list, "message3")
             end)

    registered_policies =
      Registry.select(Registry.PolicyRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

    assert {@realm_name, @mixed_policy.name} in registered_policies
  end

  defp produce_event(chan, routing_key, payload, headers, message_id) do
    Basic.publish(chan, Config.events_exchange_name!(), routing_key, payload,
      headers: headers,
      message_id: message_id
    )
  end

  defp get_policy_process(realm_name, policy) do
    case PolicyProcess.start_link(realm_name: realm_name, policy: policy) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid
    end
  end

  defp generate_routing_key(realm, policy) do
    "#{realm}_#{policy}"
  end
end
