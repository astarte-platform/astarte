#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

  import Astarte.Common.Generators.Timestamp
  import Astarte.Core.Generators.Device
  import Astarte.Core.Generators.Realm
  import Astarte.Core.Generators.Triggers.SimpleEvents.DeviceConnectedEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.DeviceDeletionFinishedEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.DeviceDeletionStartedEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.DeviceDisconnectedEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.DeviceErrorEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.DeviceRegisteredEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.IncomingDataEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.IncomingIntrospectionEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.InterfaceAddedEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.InterfaceMinorUpdatedEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.InterfaceRemovedEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.PathCreatedEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.PathRemovedEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.ValueChangeAppliedEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.ValueChangeEvent
  import Astarte.Core.Generators.Triggers.SimpleEvents.ValueStoredEvent

  @spec simple_event() :: StreamData.t(SimpleEvent.t())
  @spec simple_event(keyword :: keyword()) :: StreamData.t(SimpleEvent.t())
  def simple_event(params \\ []) do
    params gen all event <- event(),
                   simple_trigger_id <- simple_trigger_id(),
                   parent_trigger_id <- parent_trigger_id(),
                   realm <- realm_name(),
                   device_id <- device_encoded_id(),
                   # In the astarte documentation, the `timestamp` field is incorrectly indicated
                   # as being of type DateTime, despite being :int64 on protobuf.
                   # https://docs.astarte-platform.org/astarte/latest/060-triggers.html#simpleevent-payloads
                   timestamp <- timestamp(unit: :microsecond),
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
      {:device_connected_event, device_connected_event()},
      {:device_disconnected_event, device_disconnected_event()},
      {:device_deletion_started_event, device_deletion_started_event()},
      {:device_deletion_finished_event, device_deletion_finished_event()},
      {:device_registered_event, device_registered_event()},
      {:incoming_data_event, incoming_data_event()},
      {:value_change_event, value_change_event()},
      {:value_change_applied_event, value_change_applied_event()},
      {:path_created_event, path_created_event()},
      {:path_removed_event, path_removed_event()},
      {:value_stored_event, value_stored_event()},
      {:incoming_introspection_event, incoming_introspection_event()},
      {:interface_added_event, interface_added_event()},
      {:interface_removed_event, interface_removed_event()},
      {:interface_minor_updated_event, interface_minor_updated_event()},
      {:device_error_event, device_error_event()}
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
end
