defmodule Astarte.TriggerEngine.EventsConsumer do

  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  require Logger

  def consume(payload, headers) do
    decoded_payload = SimpleEvent.decode(payload)

    Logger.debug "consume: payload: #{inspect(decoded_payload)}, headers: #{inspect(headers)}"

    %SimpleEvent{
      device_id: device_id,
      event: {
        event_type,
        event
      },
      version: 1
    } = decoded_payload

    process_simple_event(device_id, headers, event_type, event)
  end

  def process_simple_event(device_id, headers, :value_change_event, event) do
    generated_payload =  %{
      "event_type": "value_change",
      "device_id": device_id,
      "interface": event.interface,
      "path": event.path,
      "new_value": decode_bson_value(event.new_bson_value),
      "old_value": decode_bson_value(event.new_bson_value)
    }

    {:ok, json_payload} = Poison.encode(generated_payload)

    url = "http://localhost:9876/"
    {status, response} = HTTPoison.post(url, json_payload)

    Logger.debug "http request status: #{inspect status}, got response: #{inspect response} from #{url}"
  end

  def decode_bson_value(encoded) do
    case Bson.decode(encoded) do
      %{v: value} ->
        value

      any_decoded ->
        any_decoded
    end
  end

end
