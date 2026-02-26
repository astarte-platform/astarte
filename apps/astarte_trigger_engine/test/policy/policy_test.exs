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
  use Astarte.Cases.Policy, async: true
  use ExUnitProperties

  import Mox
  import StreamData
  require Logger

  alias AMQP.Basic
  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.TriggerEngine.Config
  alias Astarte.TriggerEngine.Policy, as: PolicyProcess
  alias Astarte.TriggerEngine.Policy.Impl
  alias Astarte.TriggerEngine.Policy.State

  import Astarte.Fixtures.Policy

  setup do
    payload = "payload#{System.unique_integer()}"
    channel = "channel#{System.unique_integer()}"

    %{payload: payload, channel: channel}
  end

  @tag :unit
  property "Deliveries are acked on successful consume", %{payload: payload, channel: channel} do
    check all policy <- PolicyGenerator.policy(), meta <- meta(), retry_map <- retry_map() do
      policy_state = %State{policy: policy, retry_map: retry_map}
      delivery_tag = meta.delivery_tag
      Mox.expect(MockEventsConsumer, :consume, fn ^payload, _headers -> :ok end)
      Mimic.expect(Basic, :ack, fn ^channel, ^delivery_tag -> :ok end)

      result = Impl.handle_event(policy_state, channel, payload, meta)
      assert result.policy == policy
      assert result.retry_map == Map.delete(retry_map, meta.message_id)
    end
  end

  @tag :unit
  property "Messages are re-queued with retry handler and attempts < retry times", args do
    %{payload: payload, channel: channel} = args

    # there is 1 mandatory failure, so retry_times >= 2
    check all policy <- retry_all_policy(retry_times: integer(2..100)),
              meta <- meta(),
              attempts <- integer(0..(policy.retry_times - 2)),
              retry_map <- retry_map_with_optional(meta.message_id, attempts),
              consume_error <- retry_error() do
      policy_state = %State{policy: policy, retry_map: retry_map}
      delivery_tag = meta.delivery_tag
      expected_retry_count = Map.get(retry_map, meta.message_id, 0) + 1

      Mox.expect(MockEventsConsumer, :consume, fn ^payload, _headers -> consume_error end)

      Mimic.expect(Basic, :nack, fn ^channel, ^delivery_tag, opts ->
        assert Keyword.get(opts, :requeue)
        :ok
      end)

      %{retry_map: retry_map} = Impl.handle_event(policy_state, channel, payload, meta)
      assert Map.fetch!(retry_map, meta.message_id) == expected_retry_count
    end
  end

  @tag :unit
  property "Messages are discarded when attempts >= retry times", args do
    %{payload: payload, channel: channel} = args

    check all policy <- retry_all_policy(),
              meta <- meta(),
              attempts <- integer((policy.retry_times - 1)..100),
              retry_map <- retry_map_with(meta.message_id, attempts),
              consume_error <- retry_error() do
      policy_state = %State{policy: policy, retry_map: retry_map}
      delivery_tag = meta.delivery_tag

      Mox.expect(MockEventsConsumer, :consume, fn ^payload, _headers -> consume_error end)

      Mimic.expect(Basic, :nack, fn ^channel, ^delivery_tag, opts ->
        refute Keyword.get(opts, :requeue)
        :ok
      end)

      %{retry_map: retry_map} = Impl.handle_event(policy_state, channel, payload, meta)
      refute Map.has_key?(retry_map, meta.message_id)
    end
  end

  @tag :unit
  property "Messages are discarded when the trigger is not found", args do
    %{payload: payload, channel: channel} = args

    check all policy <- PolicyGenerator.policy(), meta <- meta(), retry_map <- retry_map() do
      policy_state = %State{policy: policy, retry_map: retry_map}
      delivery_tag = meta.delivery_tag

      Mox.expect(MockEventsConsumer, :consume, fn ^payload, _headers ->
        {:error, :trigger_not_found}
      end)

      Mimic.expect(Basic, :nack, fn ^channel, ^delivery_tag, opts ->
        refute Keyword.get(opts, :requeue)
        :ok
      end)

      %{retry_map: retry_map} = Impl.handle_event(policy_state, channel, payload, meta)
      refute Map.has_key?(retry_map, meta.message_id)
    end
  end

  defp retry_all_policy(params \\ []) do
    params = Keyword.put_new(params, :error_handlers, member_of(retry_all_handlers()))
    PolicyGenerator.policy(params)
  end

  defp discard_all_policy(params \\ []) do
    params = Keyword.put_new(params, :error_handlers, member_of(discard_all_handlers()))
    PolicyGenerator.policy(params)
  end

  defp retry_error do
    one_of([
      {:http_error, integer(400..599)},
      {:error, :connection_error}
    ])
  end

  defp meta do
    optional_map(
      %{
        delivery_tag: string(:alphanumeric),
        message_id: string(:alphanumeric),
        headers: list_of({string(:alphanumeric), atom(:alphanumeric), term()})
      },
      [:headers]
    )
  end

  defp retry_map do
    map_of(string(:alphanumeric), integer(1..100))
  end

  defp retry_map_with_optional(message_id, value) do
    gen all retry_map <- retry_map(),
            custom <- optional_map(%{message_id => constant(value)}) do
      retry_map
      |> Map.delete(message_id)
      |> Map.merge(custom)
    end
  end

  defp retry_map_with(message_id, value) do
    map(retry_map(), &Map.put(&1, message_id, value))
  end

  describe "messages are successfully retried" do
    setup %{realm_name: realm_name} do
      message_id = "message#{System.unique_integer()}"
      retry_all_policy = retry_all_policy() |> Enum.at(0)
      retry_all_routing_key = generate_routing_key(realm_name, retry_all_policy.name)

      %{
        message_id: message_id,
        retry_all_routing_key: retry_all_routing_key,
        retry_all_policy: retry_all_policy
      }
    end

    @tag :integration
    test "with retry strategy", args do
      %{
        payload: original_payload,
        retry_all_routing_key: retry_all_routing_key,
        message_id: message_id
      } = args

      MockEventsConsumer
      |> expect(:consume, 1, fn payload, _headers ->
        assert payload == original_payload
        {:http_error, 418}
      end)
      |> expect(:consume, 1, fn payload, _headers ->
        assert payload == original_payload
        :ok
      end)

      ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
        produce_event(chan, retry_all_routing_key, original_payload, [], message_id)
      end)
    end

    @tag :integration
    test "with retry strategy when consumer responds with connection_error", args do
      %{
        payload: original_payload,
        retry_all_routing_key: retry_all_routing_key,
        message_id: message_id
      } = args

      MockEventsConsumer
      |> expect(:consume, 1, fn payload, _headers ->
        assert payload == original_payload
        {:error, :connection_error}
      end)
      |> expect(:consume, 1, fn payload, _headers ->
        assert payload == original_payload
        :ok
      end)

      ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
        produce_event(chan, retry_all_routing_key, original_payload, [], message_id)
      end)
    end

    test "with mixed policies", args do
      %{
        payload: original_payload,
        realm_name: realm_name
      } = args

      policy = %Policy{
        name: "mixed",
        maximum_capacity: 100,
        retry_times: 10,
        error_handlers: [
          %Handler{on: %ErrorKeyword{keyword: "server_error"}, strategy: "discard"},
          %Handler{on: %ErrorRange{error_codes: [401, 402, 403, 404]}, strategy: "retry"}
        ]
      }

      routing_key = generate_routing_key(realm_name, policy.name)
      Mox.allow(MockEventsConsumer, self(), get_policy_process(realm_name, policy))

      MockEventsConsumer
      |> expect(:consume, 10, fn payload, _headers ->
        assert payload == original_payload
        {:http_error, 404}
      end)
      |> expect(:consume, 1, fn payload, _headers ->
        assert payload == original_payload
        {:http_error, 500}
      end)
      |> expect(:consume, 1, fn payload, _headers ->
        assert payload == original_payload
        :ok
      end)

      ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
        produce_event(chan, routing_key, original_payload, [], "message1")
      end)

      ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
        produce_event(chan, routing_key, original_payload, [], "message2")
      end)

      ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
        produce_event(chan, routing_key, original_payload, [], "message3")
      end)
    end
  end

  describe "messages are discarded" do
    setup %{realm_name: realm_name} do
      retry_all_policy = retry_all_policy() |> Enum.at(0)
      retry_all_routing_key = generate_routing_key(realm_name, retry_all_policy.name)
      discard_all_policy = discard_all_policy() |> Enum.at(0)
      discard_all_routing_key = generate_routing_key(realm_name, discard_all_policy.name)
      message_id = "message#{System.unique_integer()}"

      Mox.allow(MockEventsConsumer, self(), get_policy_process(realm_name, retry_all_policy))

      %{
        message_id: message_id,
        retry_all_routing_key: retry_all_routing_key,
        retry_all_policy: retry_all_policy,
        discard_all_routing_key: discard_all_routing_key,
        discard_all_policy: discard_all_policy
      }
    end

    test "with retry strategy policy when delivery fails >= retry_times", args do
      %{
        payload: original_payload,
        retry_all_policy: policy,
        retry_all_routing_key: routing_key,
        message_id: message_id
      } = args

      MockEventsConsumer
      |> expect(:consume, policy.retry_times, fn payload, _headers ->
        assert payload == original_payload
        {:http_error, 418}
      end)

      ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
        produce_event(chan, routing_key, original_payload, [], message_id)
      end)
    end

    test "with discard strategy when delivery fails", args do
      %{
        payload: original_payload,
        discard_all_routing_key: routing_key,
        message_id: message_id
      } = args

      MockEventsConsumer
      |> expect(:consume, 1, fn payload, _headers ->
        assert payload == original_payload
        {:http_error, 500}
      end)

      ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
        produce_event(chan, routing_key, original_payload, [], message_id)
      end)
    end

    test "with discard strategy when consumer responds with connection_error", args do
      %{
        payload: original_payload,
        discard_all_routing_key: routing_key,
        message_id: message_id
      } = args

      MockEventsConsumer
      |> expect(:consume, 1, fn payload, _headers ->
        assert payload == original_payload
        {:error, :connection_error}
      end)

      ExRabbitPool.with_channel(:events_consumer_pool, fn {:ok, chan} ->
        produce_event(chan, routing_key, original_payload, [], message_id)
      end)
    end
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
