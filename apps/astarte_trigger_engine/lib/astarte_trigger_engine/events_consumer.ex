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
      |> execute_action(realm, action)
    else
      error ->
        Logger.warn("Error while processing event: #{inspect(error)}")
        error
    end
  end

  def event_to_payload(_realm, device_id, :device_connected_event, event, _action) do
    %{
      "event_type" => "device_connected",
      "device_id" => device_id,
      "device_ip_address" => event.device_ip_address
    }
  end

  def event_to_payload(_realm, device_id, :device_disconnected_event, _event, _action) do
    %{
      "event_type" => "device_disconnected",
      "device_id" => device_id,
    }
  end

  def event_to_payload(_realm, device_id, :incoming_data_event, event, _action) do
    %{
      "event_type" => "incoming_data",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path,
      "value" => decode_bson_value(event.bson_value)
    }
  end

  def event_to_payload(_realm, device_id, :incoming_introspection_event, event, _action) do
    %{
      "event_type" => "incoming_introspection",
      "device_id" => device_id,
      "introspection" => event.introspection
    }
  end

  def event_to_payload(_realm, device_id, :interface_added_event, event, _action) do
    %{
      "event_type" => "interface_added",
      "device_id" => device_id,
      "interface" => event.interface,
      "major_version" => event.major_version,
      "minor_version" => event.minor_version
    }
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
  end

  def event_to_payload(_realm, device_id, :interface_removed_event, event, _action) do
    %{
      "event_type" => "interface_removed",
      "device_id" => device_id,
      "interface" => event.interface,
      "major_version" => event.major_version
    }
  end

  def event_to_payload(_realm, device_id, :path_created_event, event, _action) do
    %{
      "event_type" => "path_created",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path,
      "value" => decode_bson_value(event.bson_value)
    }
  end

  def event_to_payload(_realm, device_id, :path_removed_event, event, _action) do
    %{
      "event_type" => "path_removed",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path
    }
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
  end

  def event_to_payload(_realm, device_id, :value_stored_event, event, _action) do
    %{
      "event_type" => "value_stored",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path,
      "value" => decode_bson_value(event.bson_value)
    }
  end

  def execute_action(payload, realm, action) do
    with {:ok, json_payload} = Poison.encode(payload),
         {:ok, url} <- Map.fetch(action, "http_post_url") do
      {status, response} = HTTPoison.post(url, json_payload, ["Astarte-Realm": realm, "Content-Type": "application/json"])
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
