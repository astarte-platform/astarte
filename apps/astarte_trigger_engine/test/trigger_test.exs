#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
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

    assert Trigger.from_json(doc) == expected_value
  end
end
