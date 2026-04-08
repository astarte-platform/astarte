#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Helpers.EventsConsumer do
  @moduledoc """
  Helper module for events consumer test utilities.
  """

  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.TriggerEngine.EventsConsumer
  def stub_http(validation_function), do: Mimic.stub(HTTPoison, :request, validation_function)
  def expect_http(validation_function), do: Mimic.expect(HTTPoison, :request, validation_function)

  def http_response(params), do: {:ok, struct(HTTPoison.Response, params)}
  def network_error(reason \\ "econnrefused"), do: {:error, %HTTPoison.Error{reason: reason}}

  def build_headers(realm_name, trigger) do
    trigger_id = trigger.trigger_uuid |> UUID.binary_to_string!()

    %{"x_astarte_realm" => realm_name, "x_astarte_parent_trigger_id" => trigger_id}
  end

  def consume(event, realm_name, trigger) do
    headers = build_headers(realm_name, trigger)
    EventsConsumer.consume(event, headers)
  end

  def consume(event, realm_name, trigger, validation_function)
      when is_function(validation_function, 5) do
    headers = build_headers(realm_name, trigger)
    status_code = StreamData.integer(200..599) |> Enum.at(0)

    wrapped_validation_function = fn method, url, payload, headers, opts ->
      result = validation_function.(method, url, payload, headers, opts)

      if http_result?(result), do: result, else: http_response(status_code: status_code)
    end

    expect_http(wrapped_validation_function)
    EventsConsumer.consume(event, headers)
  end

  def static_headers(trigger) do
    trigger.action
    |> Jason.decode!()
    |> Map.get("http_static_headers", %{})
  end

  def json_event(encoded_simple_event) do
    %{event: {_type, event}} = encoded_simple_event |> SimpleEvent.decode()
    Jason.encode!(event)
  end

  defp http_result?({:ok, %HTTPoison.Response{}}), do: true
  defp http_result?({:ok, %HTTPoison.AsyncResponse{}}), do: true
  defp http_result?({:ok, %HTTPoison.MaybeRedirect{}}), do: true
  defp http_result?({:error, %HTTPoison.Error{}}), do: true
  defp http_result?(_other), do: false
end
