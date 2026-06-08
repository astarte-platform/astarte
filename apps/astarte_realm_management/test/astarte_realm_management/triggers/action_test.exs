#
# This file is part of Astarte.
#
# Copyright 2023 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.Triggers.ActionTest do
  use ExUnit.Case, async: true

  @moduletag :trigger_actions

  alias Astarte.RealmManagement.Triggers.Action
  alias Astarte.RealmManagement.Triggers.Trigger

  describe "well-formed HTTP action is correctly encoded" do
    test "when headers are set" do
      action = %Action{
        http_url: "https://example.com/",
        http_method: "put",
        http_static_headers: %{
          "Foo" => "Bar",
          "Key" => "Value"
        }
      }

      jason_out_map =
        action
        |> Jason.encode!()
        |> Jason.decode!()

      assert %{
               "http_url" => "https://example.com/",
               "http_method" => "put",
               "http_static_headers" => %{"Foo" => "Bar", "Key" => "Value"}
             } = jason_out_map
    end
  end

  describe "well-formed AMQPAction is correctly encoded" do
    test "when all is set" do
      action = %Action{
        amqp_exchange: "astarte_events_test_custom_exchange",
        amqp_routing_key: "test_routing_key",
        amqp_message_persistent: true,
        amqp_message_expiration_ms: 5000,
        amqp_message_priority: 3
      }

      jason_out_map =
        action
        |> Jason.encode!()
        |> Jason.decode!()

      assert jason_out_map == %{
               "amqp_exchange" => "astarte_events_test_custom_exchange",
               "amqp_routing_key" => "test_routing_key",
               "amqp_message_persistent" => true,
               "amqp_message_expiration_ms" => 5000,
               "amqp_message_priority" => 3
             }
    end

    test "when message priority is not set (it is omitted)" do
      action = %Action{
        amqp_exchange: "astarte_events_test_custom_exchange",
        amqp_routing_key: "test_routing_key",
        amqp_message_persistent: false,
        amqp_message_expiration_ms: 5000
      }

      jason_out_map =
        action
        |> Jason.encode!()
        |> Jason.decode!()

      assert jason_out_map == %{
               "amqp_exchange" => "astarte_events_test_custom_exchange",
               "amqp_routing_key" => "test_routing_key",
               "amqp_message_persistent" => false,
               "amqp_message_expiration_ms" => 5000
             }
    end

    test "when headers are set" do
      action = %Action{
        amqp_exchange: "astarte_events_test_custom_exchange",
        amqp_routing_key: "test",
        amqp_message_persistent: true,
        amqp_message_expiration_ms: 100,
        amqp_static_headers: %{
          "Foo" => "Bar",
          "X-Test" => "Test"
        }
      }

      jason_out_map =
        action
        |> Jason.encode!()
        |> Jason.decode!()

      assert jason_out_map == %{
               "amqp_exchange" => "astarte_events_test_custom_exchange",
               "amqp_routing_key" => "test",
               "amqp_message_persistent" => true,
               "amqp_message_expiration_ms" => 100,
               "amqp_static_headers" => %{
                 "Foo" => "Bar",
                 "X-Test" => "Test"
               }
             }
    end
  end

  test "does nothing with unknown action fields" do
    action = %{foo: "bar"}
    input = %{name: "test", policy: "ok", action: action}

    updated = Trigger.move_action(input)
    refute Map.has_key?(updated, :amqp_action)
    refute Map.has_key?(updated, :http_action)
  end
end
