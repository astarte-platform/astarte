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

defmodule Astarte.Events.TriggersHandler.CoreTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget

  alias Astarte.Core.Generators.Triggers.SimpleEvents.SimpleEvent, as: SimpleEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.IncomingDataEvent,
    as: IncomingDataEventGenerator

  alias Astarte.Events.AMQPEvents
  alias Astarte.Events.AMQPTriggers
  alias Astarte.Events.TriggersHandler.Core

  @device_id "f0VMRgIBAQAAAAAAAAAAAA"
  @routing_key "test.routing.key"

  setup :verify_on_exit!

  describe "register_target/2" do
    setup do
      realm = "autotestrealm#{System.unique_integer([:positive])}"
      exchange = "exchange_#{System.unique_integer([:positive])}"

      {:ok, realm: realm, exchange: exchange}
    end

    test "returns :ok for default exchange (nil)", %{realm: realm} do
      target = %AMQPTriggerTarget{exchange: nil}

      reject(&AMQPTriggers.declare_exchange/2)
      assert Core.register_target(realm, target) == :ok
    end

    test "declares exchange when exchange is not nil",
         %{realm: realm, exchange: exchange} do
      target = %AMQPTriggerTarget{exchange: exchange}

      AMQPTriggers
      |> expect(:declare_exchange, fn fn_realm, fn_exchange ->
        assert fn_realm == realm
        assert fn_exchange == exchange
        :ok
      end)

      assert Core.register_target(realm, target) == :ok
    end
  end

  describe "dispatch_event/3" do
    setup do
      realm = "autotestrealm#{System.unique_integer([:positive])}"
      exchange = "exchange_#{System.unique_integer([:positive])}"

      simple_event =
        SimpleEventGenerator.simple_event(
          realm: realm,
          device_id: @device_id
        )
        |> Enum.at(0)

      simple_event_trigger_engine =
        SimpleEventGenerator.simple_event(
          realm: realm,
          device_id: @device_id,
          event: {:incoming_data_event, IncomingDataEventGenerator.incoming_data_event()}
        )
        |> Enum.at(0)

      target_default = %AMQPTriggerTarget{
        exchange: nil,
        routing_key: @routing_key,
        static_headers: [{"custom_header", "custom_value"}],
        message_expiration_ms: 5000,
        message_priority: 5,
        message_persistent: true
      }

      target_custom = %AMQPTriggerTarget{
        exchange: exchange,
        routing_key: @routing_key,
        static_headers: [],
        message_expiration_ms: nil,
        message_priority: nil,
        message_persistent: false
      }

      target_trigger_engine = %AMQPTriggerTarget{
        exchange: nil,
        routing_key: "trigger_engine",
        static_headers: [],
        message_expiration_ms: nil,
        message_priority: nil,
        message_persistent: false
      }

      {:ok,
       simple_event_default: simple_event,
       simple_event_trigger_engine: simple_event_trigger_engine,
       target_default: target_default,
       target_custom: target_custom,
       target_trigger_engine: target_trigger_engine,
       realm: realm,
       exchange: exchange}
    end

    test "publishes event to default exchange with correct headers", %{
      simple_event_default: simple_event,
      target_default: target,
      realm: realm
    } do
      expected_routing_key = @routing_key
      expected_payload = SimpleEvent.encode(simple_event)

      AMQPEvents
      |> expect(:publish, fn routing_key, payload, opts ->
        assert routing_key == expected_routing_key
        assert payload == expected_payload

        # Check headers in opts
        headers_opt = Enum.find(opts, fn {k, _} -> k == :headers end)
        assert headers_opt != nil
        {_, headers} = headers_opt

        header_map = Enum.into(headers, %{})
        assert header_map["x_astarte_realm"] == realm
        assert header_map["x_astarte_device_id"] == @device_id

        assert header_map["x_astarte_event_type"] ==
                 elem(simple_event.event, 0) |> Atom.to_string()

        assert header_map["custom_header"] == "custom_value"

        # Verify trigger IDs are converted to strings
        simple_trigger_str = UUID.binary_to_string!(simple_event.simple_trigger_id)
        parent_trigger_str = UUID.binary_to_string!(simple_event.parent_trigger_id)
        assert header_map["x_astarte_simple_trigger_id"] == simple_trigger_str
        assert header_map["x_astarte_parent_trigger_id"] == parent_trigger_str

        :ok
      end)

      assert Core.dispatch_event(simple_event, target, nil) == :ok
    end

    test "includes message expiration in opts when set", %{
      simple_event_default: simple_event,
      target_default: target
    } do
      AMQPEvents
      |> expect(:publish, fn _routing_key, _payload, opts ->
        expiration_opt = Enum.find(opts, fn {k, _} -> k == :expiration end)
        assert expiration_opt != nil
        {_, expiration_value} = expiration_opt
        assert expiration_value == "5000"
        :ok
      end)

      Core.dispatch_event(simple_event, target, nil)
    end

    test "includes message priority in opts when set", %{
      simple_event_default: simple_event,
      target_default: target
    } do
      AMQPEvents
      |> expect(:publish, fn _routing_key, _payload, opts ->
        priority_opt = Enum.find(opts, fn {k, _} -> k == :priority end)
        assert priority_opt != nil
        {_, priority_value} = priority_opt
        assert priority_value == 5
        :ok
      end)

      Core.dispatch_event(simple_event, target, nil)
    end

    test "includes persistent flag in opts when set", %{
      simple_event_default: simple_event,
      target_default: target
    } do
      AMQPEvents
      |> expect(:publish, fn _routing_key, _payload, opts ->
        persistent_opt = Enum.find(opts, fn {k, _} -> k == :persistent end)
        assert persistent_opt != nil
        {_, persistent_value} = persistent_opt
        assert persistent_value == true
        :ok
      end)

      Core.dispatch_event(simple_event, target, nil)
    end

    test "includes message_id in opts", %{
      simple_event_default: simple_event,
      target_default: target
    } do
      AMQPEvents
      |> expect(:publish, fn _routing_key, _payload, opts ->
        message_id_opt = Enum.find(opts, fn {k, _} -> k == :message_id end)
        assert message_id_opt != nil
        {_, message_id} = message_id_opt
        assert is_binary(message_id)
        # Message ID should be in format: realm-device_id-timestamp-random
        assert String.contains?(message_id, "-")
        :ok
      end)

      Core.dispatch_event(simple_event, target, nil)
    end

    test "publishes event to custom exchange", %{
      simple_event_default: simple_event,
      target_custom: target,
      exchange: exchange,
      realm: realm
    } do
      AMQPTriggers
      |> expect(:publish, fn realm_name, exchange_name, routing_key, payload, opts ->
        assert realm_name == realm
        assert exchange_name == exchange
        assert routing_key == @routing_key
        assert payload == SimpleEvent.encode(simple_event)
        assert is_list(opts)
        :ok
      end)

      assert Core.dispatch_event(simple_event, target, nil) == :ok
    end

    test "updates routing key to realm_policy format when routing key is trigger_engine", %{
      simple_event_trigger_engine: simple_event,
      target_trigger_engine: target,
      realm: realm
    } do
      policy_name = "my_policy"

      AMQPEvents
      |> expect(:publish, fn routing_key, _payload, _opts ->
        assert routing_key == "#{realm}_#{policy_name}"
        :ok
      end)

      Core.dispatch_event(simple_event, target, policy_name)
    end

    test "uses @default policy when policy_name is nil", %{
      simple_event_trigger_engine: simple_event,
      target_trigger_engine: target,
      realm: realm
    } do
      AMQPEvents
      |> expect(:publish, fn routing_key, _payload, _opts ->
        assert routing_key == "#{realm}_@default"
        :ok
      end)

      Core.dispatch_event(simple_event, target, nil)
    end

    test "adds policy header when routing key is trigger_engine", %{
      simple_event_trigger_engine: simple_event,
      target_trigger_engine: target
    } do
      policy_name = "production_policy"

      AMQPEvents
      |> expect(:publish, fn _routing_key, _payload, opts ->
        headers_opt = Enum.find(opts, fn {k, _} -> k == :headers end)
        {_, headers} = headers_opt

        header_map = Enum.into(headers, %{})
        assert header_map["x_astarte_trigger_policy"] == policy_name
        :ok
      end)

      Core.dispatch_event(simple_event, target, policy_name)
    end

    test "preserves original routing key when not trigger_engine", %{
      simple_event_trigger_engine: simple_event,
      target_trigger_engine: target
    } do
      policy_name = "some_policy"

      updated_target = %{target | routing_key: "custom.routing.key"}

      AMQPEvents
      |> expect(:publish, fn routing_key, _payload, _opts ->
        # Should not be modified
        assert routing_key == "custom.routing.key"
        :ok
      end)

      Core.dispatch_event(simple_event, updated_target, policy_name)
    end

    test "does not add policy header when routing key is not trigger_engine", %{
      simple_event_trigger_engine: simple_event,
      target_trigger_engine: target
    } do
      policy_name = "some_policy"

      updated_target = %{target | routing_key: "custom.routing.key"}

      AMQPEvents
      |> expect(:publish, fn _routing_key, _payload, opts ->
        headers_opt = Enum.find(opts, fn {k, _} -> k == :headers end)
        {_, headers} = headers_opt

        header_map = Enum.into(headers, %{})
        assert header_map["x_astarte_trigger_policy"] == nil
        :ok
      end)

      Core.dispatch_event(simple_event, updated_target, policy_name)
    end

    test "retries publish on error", %{
      simple_event_default: simple_event,
      target_default: target
    } do
      # First call fails, second succeeds
      AMQPEvents
      |> expect(:publish, fn _, _, _ -> {:error, :connection_lost} end)
      |> expect(:publish, fn _, _, _ -> :ok end)

      # Should not raise and eventually return :ok
      assert Core.dispatch_event(simple_event, target, nil) == :ok
    end

    test "handles multiple events in sequence", %{
      simple_event_default: simple_event,
      target_default: target_default,
      realm: realm
    } do
      target1 = target_default

      target2 = %AMQPTriggerTarget{
        exchange: "triggers",
        routing_key: "trigger_engine",
        static_headers: [],
        message_expiration_ms: nil,
        message_priority: nil,
        message_persistent: false
      }

      AMQPEvents
      |> expect(:publish, fn @routing_key, _payload, _opts ->
        :ok
      end)

      AMQPTriggers
      |> expect(:publish, fn r, exchange, routing_key, _payload, _opts ->
        assert r == realm
        assert exchange == "triggers"
        assert routing_key == "#{realm}_@default"
        :ok
      end)

      assert Core.dispatch_event(simple_event, target1, nil) == :ok
      assert Core.dispatch_event(simple_event, target2, nil) == :ok
    end
  end
end
