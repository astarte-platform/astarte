# Copyright 2018-2024 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.AppEngine.API.Rooms.EventsDispatcher do
  @moduledoc """
  Dispatches incoming events to their room
  """

  alias Astarte.AppEngine.API.Rooms.Room
  alias Astarte.AppEngine.API.RPC.DataUpdaterPlant
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent

  require Logger

  def dispatch(serialized_simple_event) do
    simple_event = SimpleEvent.decode(serialized_simple_event)

    %SimpleEvent{
      simple_trigger_id: simple_trigger_id,
      parent_trigger_id: parent_trigger_id,
      realm: realm,
      device_id: device_id,
      timestamp: timestamp_ms,
      event: {_event_type, event}
    } = simple_event

    timestamp =
      case timestamp_ms do
        nil ->
          DateTime.utc_now()

        timestamp_ms when is_integer(timestamp_ms) ->
          DateTime.from_unix!(timestamp_ms, :millisecond)
      end

    with {:room_pid, [{pid, _}]} <-
           {:room_pid,
            Registry.lookup(Registry.AstarteRooms, {:parent_trigger_id, parent_trigger_id})},
         :ok <- Room.broadcast_event(pid, simple_trigger_id, device_id, timestamp, event) do
      :ok
    else
      {:room_pid, []} ->
        # The room is dead, uninstall the trigger
        _ =
          Logger.warning("Dispatch: unexisting room for event #{inspect(simple_event)}.",
            tag: "unexisting_room_for_event"
          )

        :telemetry.execute(
          [:astarte, :appengine, :channels, :event_discarded],
          %{},
          %{realm: realm}
        )

        DataUpdaterPlant.delete_volatile_trigger(realm, device_id, simple_trigger_id)
        {:error, :no_room_for_event}

      {:error, :trigger_not_found} ->
        # The room has unwatched the trigger, uninstall it again
        _ =
          Logger.warning("Dispatch: trigger not found for event #{inspect(simple_event)}.",
            tag: "room_trigger_not_found"
          )

        :telemetry.execute(
          [:astarte, :appengine, :channels, :event_discarded],
          %{},
          %{realm: realm}
        )

        DataUpdaterPlant.delete_volatile_trigger(realm, device_id, simple_trigger_id)
        {:error, :trigger_not_found}

      {:error, reason} ->
        # Dispatch error
        _ =
          Logger.warning(
            "Dispatch: failed for event #{inspect(simple_event)} with reason #{reason}.",
            tag: "room_failed_dispatch"
          )

        :telemetry.execute(
          [:astarte, :appengine, :channels, :event_discarded],
          %{},
          %{realm: realm}
        )

        {:error, :dispatch_error}
    end
  end
end
