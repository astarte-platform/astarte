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
      process_simple_event(realm, device_id, event_type, event, action)
    else
      error ->
        Logger.warn("Error while processing event: #{inspect(error)}")
        error
    end
  end

  def process_simple_event(realm, device_id, :value_change_event, event, action) do
    generated_payload =  %{
      "event_type" => "value_change",
      "device_id" => device_id,
      "interface" => event.interface,
      "path" => event.path,
      "new_value" => decode_bson_value(event.new_bson_value),
      "old_value" => decode_bson_value(event.old_bson_value)
    }

    with {:ok, json_payload} = Poison.encode(generated_payload),
         {:ok, url} <- Map.fetch(action, "http_post_url") do
      {status, response} = HTTPoison.post(url, json_payload, ["Astarte-Realm": realm])
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
