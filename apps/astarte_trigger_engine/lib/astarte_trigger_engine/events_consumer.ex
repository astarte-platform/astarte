#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.TriggerEngine.EventsConsumer do
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.DataAccess.Database
  alias Astarte.TriggerEngine.Config
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  require Logger

  defmodule Behaviour do
    @callback consume(payload :: binary, headers :: map) :: :ok | {:error, reason :: atom}
  end

  @behaviour Astarte.TriggerEngine.EventsConsumer.Behaviour

  @impl true
  def consume(payload, headers) do
    {:ok, realm} = Map.fetch(headers, "x_astarte_realm")

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

    timestamp_ms =
      case decoded_payload.timestamp do
        nil ->
          DateTime.utc_now()
          |> DateTime.from_unix(:millisecond)

        timestamp when is_integer(timestamp) ->
          timestamp
      end

    :telemetry.execute([:astarte, :trigger_engine, :consumed_event], %{}, %{realm: realm})
    handle_simple_event(realm, device_id, headers, event_type, event, timestamp_ms)
  end

  defp handle_simple_event(realm, device_id, headers_map, event_type, event, timestamp_ms) do
    with {:ok, trigger_id} <- Map.fetch(headers_map, "x_astarte_parent_trigger_id"),
         {:ok, action} <- retrieve_trigger_configuration(realm, trigger_id),
         {:ok, payload} <-
           event_to_payload(realm, device_id, event_type, event, action, timestamp_ms),
         {:ok, headers} <- event_to_headers(realm, device_id, event_type, event, action),
         :ok <- execute_action(payload, headers, action) do
      :telemetry.execute(
        [:astarte, :trigger_engine, :http_action_executed],
        %{},
        %{realm: realm, status: :ok}
      )

      :ok
    else
      {:error, :client_error} ->
        :telemetry.execute(
          [:astarte, :trigger_engine, :http_action_executed],
          %{},
          %{realm: realm, status: :client_error}
        )

        :client_error

      {:error, :server_error} ->
        :telemetry.execute(
          [:astarte, :trigger_engine, :http_action_executed],
          %{},
          %{realm: realm, status: :server_error}
        )

        :server_error

      {:error, :connection_error} ->
        :telemetry.execute(
          [:astarte, :trigger_engine, :http_action_executed],
          %{},
          %{realm: realm, status: :connection_error}
        )

        :connection_error

      error ->
        Logger.warn("Error while processing event: #{inspect(error)}")

        error
    end
  end

  defp build_values_map(realm, device_id, event_type, event) do
    base_values = %{
      "realm" => realm,
      "device_id" => device_id,
      "event_type" => to_string(event_type)
    }

    # TODO: check this with object aggregations
    Map.from_struct(event)
    |> Enum.reduce(base_values, fn {item_key, item_value}, acc ->
      case item_key do
        :bson_value ->
          %{"v" => decoded_value} = Cyanide.decode!(item_value)
          Map.put(acc, "value", decoded_value)

        :old_bson_value ->
          %{"v" => decoded_value} = Cyanide.decode!(item_value)
          Map.put(acc, "old_value", decoded_value)

        :new_bson_value ->
          %{"v" => decoded_value} = Cyanide.decode!(item_value)
          Map.put(acc, "new_value", decoded_value)

        _ ->
          Map.put(acc, to_string(item_key), item_value)
      end
    end)
  end

  defp event_to_headers(realm, _device_id, _event_type, _event, %{
         "template" => _template,
         "template_type" => "mustache"
       }) do
    {:ok, ["Astarte-Realm": realm, "Content-Type": "text/plain"]}
  end

  defp event_to_headers(realm, _device_id, _event_type, _event, _action) do
    {:ok, ["Astarte-Realm": realm, "Content-Type": "application/json"]}
  end

  defp event_to_payload(
         realm,
         device_id,
         event_type,
         event,
         %{
           "template" => template,
           "template_type" => "mustache"
         },
         _timestamp_ms
       ) do
    values = build_values_map(realm, device_id, event_type, event)

    {:ok, :bbmustache.render(template, values, key_type: :binary)}
  end

  defp event_to_payload(_realm, device_id, _event_type, event, _action, timestamp_ms) do
    with {:ok, timestamp} <- DateTime.from_unix(timestamp_ms, :millisecond) do
      %{
        "timestamp" => timestamp,
        "device_id" => device_id,
        "event" => event
      }
      |> Jason.encode()
    end
  end

  defp execute_action(payload, headers, action) do
    with {:ok, url} <- Map.fetch(action, "http_post_url"),
         {:ok, response} <- HTTPoison.post(url, payload, headers) do
      %HTTPoison.Response{status_code: status_code} = response

      case status_code do
        status_code when status_code in 200..399 ->
          Logger.debug("http request status: :ok, got response: #{inspect(response)} from #{url}")
          :ok

        status_code when status_code in 400..499 ->
          Logger.warn(
            "Error while processing event: #{inspect(response)}. Payload: #{inspect(payload)}, headers: #{
              inspect(headers)
            }, action: #{inspect(action)}"
          )

          {:error, :client_error}

        status_code when status_code >= 500 ->
          Logger.warn(
            "Error while processing event: #{inspect(response)}. Payload: #{inspect(payload)}, headers: #{
              inspect(headers)
            }, action: #{inspect(action)}"
          )

          {:error, :server_error}
      end
    else
      {:error, reason} ->
        Logger.warn(
          "Error while processing the post request: #{inspect(reason)}. Payload: #{
            inspect(payload)
          }, headers: #{inspect(headers)}, action: #{inspect(action)}"
        )

        {:error, :connection_error}

      error ->
        Logger.warn("Error while processing event: #{inspect(error)}")
        error
    end
  end

  defp retrieve_trigger_configuration(realm_name, trigger_id) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT value FROM kv_store WHERE group='triggers' AND key=:trigger_id;"
      )
      |> DatabaseQuery.put(:trigger_id, trigger_id)

    with {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, result} <- DatabaseQuery.call(client, query),
         [value: trigger_data] <- DatabaseResult.head(result),
         trigger <- Trigger.decode(trigger_data),
         {:ok, action} <- Jason.decode(trigger.action) do
      {:ok, action}
    else
      {:error, :database_connection_error} ->
        Logger.warn("Database connection error.")
        {:error, :database_connection_error}

      error ->
        Logger.warn("Error while processing event: #{inspect(error)}")
        {:error, :trigger_not_found}
    end
  end
end
