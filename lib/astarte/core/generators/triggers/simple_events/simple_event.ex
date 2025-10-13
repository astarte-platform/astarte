#   field :interface_minor_updated_event, 17,
#     type: Astarte.Core.Triggers.SimpleEvents.InterfaceMinorUpdatedEvent,
#     json_name: "interfaceMinorUpdatedEvent",
#     oneof: 0

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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.SimpleEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event struct.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent

  alias Astarte.Common.Generators.Timestamp, as: TimestampGenerator
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Realm, as: RealmGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.DeviceConnectedEvent,
    as: DeviceConnectedEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.DeviceDisconnectedEvent,
    as: DeviceDisconnectedEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.DeviceErrorEvent,
    as: DeviceErrorEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.IncomingDataEvent,
    as: IncomingDataEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.IncomingIntrospectionEvent,
    as: IncomingIntrospectionEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.InterfaceAddedEvent,
    as: InterfaceAddedEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.InterfaceMinorUpdatedEvent,
    as: InterfaceMinorUpdatedEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.InterfaceRemovedEvent,
    as: InterfaceRemovedEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.PathCreatedEvent,
    as: PathCreatedEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.PathRemovedEvent,
    as: PathRemovedEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.ValueChangeAppliedEvent,
    as: ValueChangeAppliedEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.ValueChangeEvent,
    as: ValueChangeEventGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.ValueStoredEvent,
    as: ValueStoredEventGenerator

  @spec simple_event() :: StreamData.t(SimpleEvent.t())
  @spec simple_event(keyword :: keyword()) :: StreamData.t(SimpleEvent.t())
  def simple_event(params \\ []) do
    params gen all event <- event(),
                   simple_trigger_id <- simple_trigger_id(),
                   parent_trigger_id <- parent_trigger_id(),
                   realm <- realm(),
                   device_id <- device_id(),
                   timestamp <- timestamp(),
                   params: params do
      %SimpleEvent{
        event: event,
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        realm: realm,
        device_id: device_id,
        timestamp: timestamp
      }
    end
  end

  defp event do
    [
      {:device_connected_event, DeviceConnectedEventGenerator.device_connected_event()},
      {:device_disconnected_event, DeviceDisconnectedEventGenerator.device_disconnected_event()},
      {:incoming_data_event, IncomingDataEventGenerator.incoming_data_event()},
      {:value_change_event, ValueChangeEventGenerator.value_change_event()},
      {:value_change_applied_event,
       ValueChangeAppliedEventGenerator.value_change_applied_event()},
      {:path_created_event, PathCreatedEventGenerator.path_created_event()},
      {:path_removed_event, PathRemovedEventGenerator.path_removed_event()},
      {:value_stored_event, ValueStoredEventGenerator.value_stored_event()},
      {:incoming_introspection_event,
       IncomingIntrospectionEventGenerator.incoming_introspection_event()},
      {:interface_added_event, InterfaceAddedEventGenerator.interface_added_event()},
      {:interface_removed_event, InterfaceRemovedEventGenerator.interface_removed_event()},
      {:interface_minor_updated_event,
       InterfaceMinorUpdatedEventGenerator.interface_minor_updated_event()},
      {:device_error_event, DeviceErrorEventGenerator.device_error_event()}
    ]
    # NOTE
    # Using `one_of()` would be the right solution, but StreamData's `specs` do not recognise
    # an `atom` within a `tuple` as `StreamData` and therefore as a generator.
    # one_of()
    |> member_of()
    |> bind(fn {atom, gen} -> gen |> map(&{atom, &1}) end)
  end

  defp simple_trigger_id, do: repeatedly(fn -> UUID.uuid4(:raw) end)
  defp parent_trigger_id, do: repeatedly(fn -> UUID.uuid4(:raw) end)
  defp device_id, do: DeviceGenerator.encoded_id()
  defp realm, do: RealmGenerator.realm_name()

  # In the astarte documentation, the `timestamp` field is incorrectly indicated
  # as being of type DateTime, despite being :int64 on protobuf.
  # https://docs.astarte-platform.org/astarte/latest/060-triggers.html#simpleevent-payloads
  defp timestamp, do: TimestampGenerator.timestamp(unit: :microsecond)
end
