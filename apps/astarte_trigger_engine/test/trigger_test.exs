#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.TriggerEngine.TriggerTest do
  use ExUnit.Case
  alias Astarte.TriggerEngine.Trigger

  test "JSON deserialization" do
    doc = """
      {
        "name": "array_value_trigger",
        "description": "this is a test trigger.",

        "interface": "com.example.array",
        "path": "/sensor/0/values",
        "event": "incoming_data",

        "queue": "my_queue_for_http_200",

        "action": {
          "type": "push_to_http",
          "method": "POST",
          "url": "http://www.astarte-example.com/push_event.php?device=%{device_id}",
          "headers": ["Interface: %{interface_name}"],
          "body_type": "json",
          "body": {
            "type": "astarte.templates.for_each",
            "var": "value.example_array",
            "current_item_var_name": "current_item",
            "repeat":  {"example_value": {"type": "astarte.templates.text", "var": "current_item"}}
          }
        }
      }
    """

    expected_value = %Trigger{
      action: %Astarte.TriggerEngine.HttpRequestTemplate{
        body: %Astarte.TriggerEngine.Templating.StructTemplate{
          struct_template: %{
            "current_item_var_name" => "current_item",
            "repeat" => %{
              "example_value" => %{
                "type" => "astarte.templates.text",
                "var" => "current_item"
              }
            },
            "type" => "astarte.templates.for_each",
            "var" => "value.example_array"
          }
        },
        body_type: :json,
        headers: %Astarte.TriggerEngine.Templating.HeadersTemplate{
          headers: ["Interface: %{interface_name}"]
        },
        method: "POST",
        url: %Astarte.TriggerEngine.Templating.URLTemplate{
          url: "http://www.astarte-example.com/push_event.php?device=%{device_id}"
        }
      },
      name: "array_value_trigger",
      queue: "my_queue_for_http_200",
      simple_triggers: %{
        event: :incoming_data,
        interface: "com.example.array",
        path: "/sensor/0/values"
      }
    }

    assert Trigger.from_json(doc) == {:ok, expected_value}
  end

  test "invalid JSON deserialization" do
    invalid_doc = """
        "name": "missing_opening_bracket",
        "description": "this is a test trigger.",

        "interface": "com.example.array",
        "path": "/sensor/0/values",
        "event": "incoming_data",

        "queue": "my_queue_for_http_200",

        "action": {
          "type": "push_to_http",
          "method": "POST",
          "url": "http://www.astarte-example.com/push_event.php?device=%{device_id}",
          "headers": ["Interface: %{interface_name}"],
          "body_type": "json",
          "body": {
            "type": "astarte.templates.for_each",
            "var": "value.example_array",
            "current_item_var_name": "current_item",
            "repeat":  {"example_value": {"type": "astarte.templates.text", "var": "current_item"}}
          }
        }
      }
    """

    assert Trigger.from_json(invalid_doc) == {:error, :invalid_json}
  end

  test "invalid action" do
    invalid_action_doc = """
      {
        "name": "invalid_action",
        "description": "this is a test trigger.",

        "interface": "com.example.array",
        "path": "/sensor/0/values",
        "event": "incoming_data",

        "queue": "my_queue_for_http_200",

        "action": {
          "type": "invalid_action"
        }
      }
    """

    assert Trigger.from_json(invalid_action_doc) == {:error, :invalid_action}
  end

  test "invalid trigger" do
    invalid_trigger_doc = """
      {
        "name": "invalid_trigger",
        "description": "this is a test trigger.",

        "invalid_trigger": "invalid",

        "queue": "my_queue_for_http_200",

        "action": {
          "type": "push_to_http",
          "method": "POST",
          "url": "http://www.astarte-example.com/push_event.php?device=%{device_id}",
          "headers": ["Interface: %{interface_name}"],
          "body_type": "json",
          "body": {
            "type": "astarte.templates.for_each",
            "var": "value.example_array",
            "current_item_var_name": "current_item",
            "repeat":  {"example_value": {"type": "astarte.templates.text", "var": "current_item"}}
          }
        }
      }
    """

    assert Trigger.from_json(invalid_trigger_doc) == {:error, :invalid_trigger}
  end
end
