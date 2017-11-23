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

defmodule Astarte.TriggerEngine.Trigger do
  alias Astarte.TriggerEngine.Templating.HeadersTemplate
  alias Astarte.TriggerEngine.Templating.URLTemplate
  alias Astarte.TriggerEngine.Templating.StructTemplate
  alias Astarte.TriggerEngine.HttpRequestTemplate
  alias Astarte.TriggerEngine.Trigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger

  defstruct [
    :name,
    :queue,
    :simple_triggers,
    :action
  ]

  def action_from_map(%{"type" => "push_to_http"} = map) do
    # TODO: error checking
    {:ok,
      %HttpRequestTemplate{
        method: map["method"],
        url: URLTemplate.new(map["url"]),
        headers: HeadersTemplate.new(map["headers"]),
        body_type: body_type_string_to_atom(map["body_type"]),
        body: body_map_to_body_template(map["body"], map["body_type"])
      }
    }
  end

  def action_from_map(_) do
    {:error, :invalid_action}
  end

  defp body_type_string_to_atom(body_type_string) do
    case body_type_string do
      "json" -> :json
      "no_body" -> :no_body
    end
  end

  def body_map_to_body_template(map, "json") do
    StructTemplate.new(map)
  end

  def body_map_to_body_template(_map, "no_body") do
    nil
  end

  def from_json(json_document) do
    json_obj = Poison.decode!(json_document)

    %Trigger{
      name: json_obj["name"],
      queue: json_obj["queue"],
      simple_triggers: to_simple_triggers(json_obj),
      action: action_from_map(json_obj["action"])
    }
  end

  def data_trigger_event_type_to_atom(event) do
    case event do
      "incoming_data" ->
        :incoming_data
    end
  end

  def to_simple_triggers(%{"interface" => interface} = map) do
    #TODO: error checking
    {:ok,
      %{
        interface: interface,
        path: Map.get(map, "path"),
        event: data_trigger_event_type_to_atom(map["event"])
      }
    }
  end

  def to_simple_triggers(_) do
    {:error, :invalid_trigger}
  end
end
