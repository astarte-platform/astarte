#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Events.TriggersHandler.Integration.CoreTest do
  use Astarte.Cases.Data, async: true

  import Mimic

  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Events.TriggersHandler.Core
  alias Astarte.Core.Generators.Triggers.SimpleEvents.SimpleEvent, as: SimpleEventGenerator
  alias Astarte.Events.AMQPTriggers.VHostSupervisor
  alias Astarte.Events.Test.AmqpTriggers.Consumer
  alias Astarte.Events.AMQP.Vhost

  @device_id "f0VMRgIBAQAAAAAAAAAAAA"
  @routing_key "test.routing.key"

  setup :verify_on_exit!

  setup_all context do
    %{realm_name: realm_name} = context

    :ok = Vhost.create_vhost(realm_name)
    {:ok, producer} = VHostSupervisor.for_realm(realm_name, true)

    Astarte.DataAccess.Config
    |> allow(self(), producer)

    :ok = GenServer.call(producer, :start)

    :ok
  end

  setup context do
    realm_name = context[:realm_name]
    routing_key = context[:routing_key] || @routing_key
    test_process = self()

    opts = [
      realm_name: realm_name,
      routing_key: routing_key,
      ready_pid: test_process,
      wait_start: true,
      message_handler: fn payload, meta ->
        send(test_process, {:amqp_message, payload, meta})
        :ok
      end
    ]

    consumer = start_supervised!({Consumer, opts})

    Astarte.DataAccess.Config
    |> allow(self(), consumer)

    :ok = GenServer.call(consumer, :start)

    assert_receive :consumer_ready

    %{amqp_consumer: consumer, realm_name: realm_name}
  end

  describe "integration tests with AMQP" do
    setup %{realm_name: realm_name} do
      # Build the exchange name that the Consumer will use
      exchange_suffix = "events"
      exchange = "astarte_events_#{realm_name}_#{exchange_suffix}"

      simple_event =
        SimpleEventGenerator.simple_event(
          realm: realm_name,
          device_id: @device_id
        )
        |> Enum.at(0)

      target_default = %AMQPTriggerTarget{
        exchange: exchange,
        routing_key: @routing_key,
        static_headers: [{"custom_header", "custom_value"}],
        message_expiration_ms: 5000,
        message_priority: 5,
        message_persistent: true
      }

      {:ok,
       simple_event_default: simple_event, target_default: target_default, exchange: exchange}
    end

    test "publishes event to broker and consumer receives it", %{
      realm_name: realm,
      simple_event_default: simple_event,
      target_default: target
    } do
      parent_trigger_id = simple_event.parent_trigger_id
      simple_trigger_id = simple_event.simple_trigger_id
      timestamp = simple_event.timestamp
      event = simple_event.event

      # Dispatch the event to real AMQP broker
      assert Core.dispatch_event(simple_event, target, nil) == :ok

      # Wait for message to be received by consumer
      assert_receive {:amqp_message, payload, meta}

      # Verify the message content
      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: ^realm,
               timestamp: ^timestamp,
               event: ^event
             } = SimpleEvent.decode(payload)

      # Verify headers
      headers_map = amqp_headers_to_map(meta.headers)
      assert Map.get(headers_map, "x_astarte_realm") == realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == elem(event, 0) |> Atom.to_string()
      assert Map.get(headers_map, "custom_header") == "custom_value"
    end
  end

  defp amqp_headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {key, _type, value}, acc ->
      Map.put(acc, key, value)
    end)
  end
end
