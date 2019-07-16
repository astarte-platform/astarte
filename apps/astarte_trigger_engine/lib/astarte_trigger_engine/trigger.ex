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
     }}
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
    json_decode_result =
      case Jason.decode(json_document) do
        {:ok, json_obj} ->
          {:ok, json_obj}

        {:error, reason} ->
          {:error, :invalid_json}
      end

    with {:ok, json_obj} <- json_decode_result,
         name = json_obj["name"],
         queue = json_obj["queue"],
         {:ok, simple_triggers} <- to_simple_triggers(json_obj),
         {:ok, action} <- action_from_map(json_obj["action"]) do
      {:ok,
       %Trigger{
         name: name,
         queue: queue,
         simple_triggers: simple_triggers,
         action: action
       }}
    end
  end

  def data_trigger_event_type_to_atom(event) do
    case event do
      "incoming_data" ->
        :incoming_data
    end
  end

  def to_simple_triggers(%{"interface" => interface} = map) do
    # TODO: error checking
    {:ok,
     %{
       interface: interface,
       path: Map.get(map, "path"),
       event: data_trigger_event_type_to_atom(map["event"])
     }}
  end

  def to_simple_triggers(_) do
    {:error, :invalid_trigger}
  end
end
