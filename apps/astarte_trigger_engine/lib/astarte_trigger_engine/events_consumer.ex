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

defmodule Astarte.TriggerEngine.EventsConsumer do

  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.Trigger
  alias CQEx.Client, as: DatabaseClient
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  require Logger

  def consume(payload, headers) do
    headers_map = Enum.into(headers, %{})

    {:ok, realm} = Map.fetch(headers_map, "x_astarte_realm")

    decoded_payload = SimpleEvent.decode(payload)

    Logger.debug("consume: payload: #{inspect(decoded_payload)}, headers: #{inspect(headers)}")

    %SimpleEvent{
      device_id: device_id,
      event: {
        event_type,
        event
      },
      version: 1
    } = decoded_payload

    handle_simple_event(realm, device_id, headers_map, event_type, event)
  end

  def handle_simple_event(realm, device_id, headers_map, event_type, event) do
    with {:ok, trigger_id} <- Map.fetch(headers_map, "x_astarte_parent_trigger_id"),
         {:ok, action} <- retrieve_trigger_configuration(realm, trigger_id) do
      event_to_payload(realm, device_id, event_type, event, action)
      |> event_to_headers(realm, device_id, event_type, event, action)
      |> execute_action(action)
    else
      error ->
        Logger.warn("Error while processing event: #{inspect(error)}")
        error
    end
  end

  def build_values_map(realm, device_id, event_type, event) do
    base_values = %{
      "realm" => realm,
      "device_id" => device_id,
      "event_type" => to_string(event_type),
    }

    # TODO: check this with object aggregations
    Map.from_struct(event)
    |> Enum.reduce(base_values, fn {item_key, item_value}, acc ->
      case item_key do
        :bson_value ->
          %{v: decoded_value} = Bson.decode(item_value)
          Map.put(acc, "value", decoded_value)

        :old_bson_value ->
          %{v: decoded_value} = Bson.decode(item_value)
          Map.put(acc, "old_value", decoded_value)

        :new_bson_value ->
          %{v: decoded_value} = Bson.decode(item_value)
          Map.put(acc, "new_value", decoded_value)

        _ ->
          Map.put(acc, to_string(item_key), item_value)
      end
    end)
  end

  def event_to_headers({:ok, payload},
        realm,
        _device_id,
        _event_type,
        _event,
        %{"template" => _template, "template_type" => "mustache"}
      ) do
    {:ok, payload, ["Astarte-Realm": realm]}
  end

  def event_to_headers({:ok, payload}, realm, _device_id, _event_type, _event, _action) do
    {:ok, payload, ["Astarte-Realm": realm, "Content-Type": "application/json"]}
  end

  def event_to_headers(payload_result, _realm, _device_id, _event_type, _event, _action) do
    payload_result
  end

  def event_to_payload(realm, device_id, event_type, event, %{"template" => template, "template_type" => "mustache"}) do
    values = build_values_map(realm, device_id, event_type, event)

    {:ok, :bbmustache.render(template, values, [key_type: :binary])}
  end

  def event_to_payload(_realm, device_id, :device_connected_event, event, _action) do
    %{
      "event_type" => "device_connected",
      "device_id" => device_id,
      "device_ip_address" => event.device_ip_address
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :device_disconnected_event, _event, _action) do
    %{
      "event_type" => "device_disconnected",
      "device_id" => device_id,
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :incoming_data_event, event, _action) do
    %{
      "event_type" => "incoming_data",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path,
      "value" => decode_bson_value(event.bson_value)
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :incoming_introspection_event, event, _action) do
    %{
      "event_type" => "incoming_introspection",
      "device_id" => device_id,
      "introspection" => event.introspection
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :interface_added_event, event, _action) do
    %{
      "event_type" => "interface_added",
      "device_id" => device_id,
      "interface" => event.interface,
      "major_version" => event.major_version,
      "minor_version" => event.minor_version
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :interface_minor_updated_event, event, _action) do
    %{
      "event_type" => "interface_minor_updated",
      "device_id" => device_id,
      "interface" => event.interface,
      "major_version" => event.major_version,
      "old_minor_version" => event.old_minor_version,
      "new_minor_version" => event.new_minor_version
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :interface_removed_event, event, _action) do
    %{
      "event_type" => "interface_removed",
      "device_id" => device_id,
      "interface" => event.interface,
      "major_version" => event.major_version
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :path_created_event, event, _action) do
    %{
      "event_type" => "path_created",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path,
      "value" => decode_bson_value(event.bson_value)
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :path_removed_event, event, _action) do
    %{
      "event_type" => "path_removed",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :value_change_applied_event, event, _action) do
    %{
      "event_type" => "value_change_applied",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path,
      "new_value" => decode_bson_value(event.new_bson_value),
      "old_value" => decode_bson_value(event.old_bson_value)
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :value_change_event, event, _action) do
    %{
      "event_type" => "value_change",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path,
      "new_value" => decode_bson_value(event.new_bson_value),
      "old_value" => decode_bson_value(event.old_bson_value)
    }
    |> Poison.encode()
  end

  def event_to_payload(_realm, device_id, :value_stored_event, event, _action) do
    %{
      "event_type" => "value_stored",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path,
      "value" => decode_bson_value(event.bson_value)
    }
    |> Poison.encode()
  end

  def execute_action(payload_and_headers, action) do
    with {:ok, payload, headers} <- payload_and_headers,
         {:ok, url} <- Map.fetch(action, "http_post_url") do
      {status, response} = HTTPoison.post(url, payload, headers)
      Logger.debug("http request status: #{inspect status}, got response: #{inspect response} from #{url}")
      :ok
    else
      error ->
        Logger.warn("Error while processing event: #{inspect(error)}")
        error
    end
  end

  def decode_bson_value(encoded) do
    case Bson.decode(encoded) do
      %{v: value} ->
        value

      any_decoded ->
        any_decoded
    end
  end

  def retrieve_trigger_configuration(realm_name, trigger_id) do
    client =
      DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT value FROM kv_store WHERE group='triggers' AND key=:trigger_id;")
      |> DatabaseQuery.put(:trigger_id, trigger_id)

    with {:ok, result} <- DatabaseQuery.call(client, query),
         ["value": trigger_data] <- DatabaseResult.head(result),
         trigger  <- Trigger.decode(trigger_data),
         {:ok, action} <- Poison.decode(trigger.action) do
      {:ok, action}
    else
      error ->
        Logger.warn("Error while processing event: #{inspect(error)}")
        {:error, :trigger_not_found}
    end
  end

end
