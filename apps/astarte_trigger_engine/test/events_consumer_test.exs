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

defmodule Astarte.TriggerEngine.EventsConsumerTest do
  use Astarte.Cases.Database, async: true
  use Astarte.Cases.Trigger, triggers: Astarte.Fixtures.Trigger.all_triggers()
  use ExUnitProperties
  use Mimic

  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Fixtures.SimpleEvent, as: SimpleEventsFixture

  import Astarte.Helpers.EventsConsumer
  import Astarte.Fixtures.Trigger

  setup do
    event = encoded_simple_event() |> Enum.at(0)
    %{event: event}
  end

  describe "consume/2" do
    property "succeeds for valid values", %{realm_name: realm_name} do
      check all event <- encoded_simple_event(), trigger <- trigger(), code <- success_code() do
        result =
          consume(event, realm_name, trigger, fn _, _, _, _, _ ->
            http_response(status_code: code)
          end)

        assert result == :ok
      end
    end

    property "returns an error for http errors", %{realm_name: realm_name, event: event} do
      check all trigger <- trigger(), code <- error_code() do
        result =
          consume(event, realm_name, trigger, fn _, _, _, _, _ ->
            http_response(status_code: code)
          end)

        assert result == {:http_error, code}
      end
    end

    property "returns an error for invalid triggers", %{realm_name: realm_name, event: event} do
      check all trigger <- invalid_trigger() do
        assert {:error, _} = consume(event, realm_name, trigger)
      end
    end

    property "returns an error for network errors", %{realm_name: realm_name, event: event} do
      check all trigger <- trigger() do
        assert {:error, _} =
                 consume(event, realm_name, trigger, fn _, _, _, _, _ -> network_error() end)
      end
    end

    property "returns an error for triggers not installed", %{
      realm_name: realm_name,
      event: event
    } do
      check all trigger <- trigger_not_installed() do
        assert {:error, _} = consume(event, realm_name, trigger)
      end
    end
  end

  property "static headers are respected", %{realm_name: realm_name, event: event} do
    check all trigger <- trigger_with_static_headers() do
      static_headers = static_headers(trigger)

      consume(event, realm_name, trigger, fn _, _, _, headers, _ ->
        header_map = Map.new(headers)
        assert Map.intersect(static_headers, header_map) == static_headers
      end)
    end
  end

  property "valid mustache action returns the mustache template", %{
    realm_name: realm_name,
    event: event
  } do
    check all trigger <- mustache_trigger() do
      consume(event, realm_name, trigger, fn _, _, payload, headers, _ ->
        assert is_binary(payload)
        assert Keyword.fetch!(headers, :"Content-Type") == "text/plain"
      end)
    end
  end

  property "default action returns a valid json", %{realm_name: realm_name, event: event} do
    check all trigger <- default_action_trigger() do
      expected_event = json_event(event)

      consume(event, realm_name, trigger, fn _, _, payload, headers, _ ->
        assert Keyword.fetch!(headers, :"Content-Type") == "application/json"

        assert %{
                 "timestamp" => timestamp,
                 "device_id" => device_id,
                 "event" => event,
                 "trigger_name" => trigger_name
               } = Jason.decode!(payload)

        assert {:ok, _, _} = DateTime.from_iso8601(timestamp)
        assert {:ok, _} = Device.decode_device_id(device_id)
        assert trigger_name == trigger.name
        assert Jason.encode!(event) == expected_event
      end)
    end
  end

  # Generators
  defp trigger, do: member_of(triggers())
  defp trigger_with_static_headers, do: member_of(triggers_with_static_headers())
  defp mustache_trigger, do: member_of(mustache_triggers())
  defp default_action_trigger, do: member_of(default_action_triggers())
  defp invalid_trigger, do: member_of(invalid_triggers())
  defp simple_event, do: member_of(SimpleEventsFixture.simple_events())
  defp encoded_simple_event, do: map(simple_event(), &SimpleEvent.encode/1)
  defp trigger_not_installed, do: member_of(triggers_not_installed())
  defp success_code, do: integer(200..399)
  defp error_code, do: integer(400..599)
end
