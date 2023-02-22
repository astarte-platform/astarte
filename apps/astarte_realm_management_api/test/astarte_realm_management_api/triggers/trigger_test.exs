#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule Astarte.RealmManagement.API.Triggers.TriggerTest do
  use ExUnit.Case
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.RealmManagement.API.Triggers.Trigger
  alias Astarte.RealmManagement.API.Triggers.AMQPAction
  alias Astarte.RealmManagement.API.Triggers.HttpAction
  alias Astarte.RealmManagement.API.Triggers.Action
  alias Ecto.Changeset

  test "valid triggers with http action are accepted" do
    input = %{
      "name" => "test_trigger",
      "simple_triggers" => [
        %{
          "type" => "device_trigger",
          "device_id" => "*",
          "on" => "device_connected"
        }
      ],
      "action" => %{
        "http_url" => "http://www.example.com",
        "http_method" => "delete"
      }
    }

    out =
      %Trigger{}
      |> Trigger.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:ok,
            %Trigger{
              name: "test_trigger",
              action: %Action{
                http_url: "http://www.example.com",
                http_method: "delete",
                ignore_ssl_errors: false
              },
              simple_triggers: [
                %SimpleTriggerConfig{
                  device_id: "*",
                  on: "device_connected",
                  type: "device_trigger"
                }
              ]
            }} == out
  end

  test "valid triggers with http action and ignore_ssl_errors are accepted" do
    input = %{
      "name" => "test_trigger",
      "simple_triggers" => [
        %{
          "type" => "device_trigger",
          "device_id" => "*",
          "on" => "device_connected"
        }
      ],
      "action" => %{
        "http_url" => "http://www.example.com",
        "http_method" => "delete",
        "ignore_ssl_errors" => true
      }
    }

    out =
      %Trigger{}
      |> Trigger.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:ok,
            %Trigger{
              name: "test_trigger",
              action: %Action{
                http_url: "http://www.example.com",
                http_method: "delete",
                ignore_ssl_errors: true
              },
              simple_triggers: [
                %SimpleTriggerConfig{
                  device_id: "*",
                  on: "device_connected",
                  type: "device_trigger"
                }
              ]
            }} == out
  end

  test "valid triggers with old http action format are accepted" do
    input = %{
      "name" => "test_trigger",
      "simple_triggers" => [
        %{
          "type" => "device_trigger",
          "device_id" => "*",
          "on" => "device_connected"
        }
      ],
      "action" => %{
        "http_post_url" => "http://www.example.com"
      }
    }

    out =
      %Trigger{}
      |> Trigger.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:ok,
            %Trigger{
              name: "test_trigger",
              action: %Action{
                http_url: "http://www.example.com",
                http_method: "post"
              },
              simple_triggers: [
                %SimpleTriggerConfig{
                  device_id: "*",
                  on: "device_connected",
                  type: "device_trigger"
                }
              ]
            }} == out
  end

  test "valid triggers with AMQP action are accepted" do
    input = %{
      "name" => "test_trigger",
      "simple_triggers" => [
        %{
          "type" => "device_trigger",
          "device_id" => "*",
          "on" => "device_connected"
        }
      ],
      "action" => %{
        "amqp_exchange" => "astarte_events_test_custom_exchange",
        "amqp_routing_key" => "routing_key",
        "amqp_message_persistent" => true,
        "amqp_message_expiration_ms" => 5000,
        "amqp_message_priority" => 3
      }
    }

    out =
      %Trigger{}
      |> Trigger.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:ok,
            %Trigger{
              name: "test_trigger",
              action: %Action{
                amqp_exchange: "astarte_events_test_custom_exchange",
                amqp_routing_key: "routing_key",
                amqp_message_persistent: true,
                amqp_message_expiration_ms: 5000,
                amqp_message_priority: 3
              },
              simple_triggers: [
                %SimpleTriggerConfig{
                  device_id: "*",
                  on: "device_connected",
                  type: "device_trigger"
                }
              ]
            }} == out
  end

  test "absent trigger policy is set to nil" do
    input = %{
      "name" => "test_trigger",
      "simple_triggers" => [
        %{
          "type" => "device_trigger",
          "device_id" => "*",
          "on" => "device_connected"
        }
      ],
      "action" => %{
        "http_url" => "http://www.example.com",
        "http_method" => "delete"
      }
    }

    {:ok, out} =
      %Trigger{}
      |> Trigger.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert out.policy == nil
  end
end
