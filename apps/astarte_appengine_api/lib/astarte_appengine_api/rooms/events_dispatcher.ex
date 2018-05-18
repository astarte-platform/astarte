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
# Copyright (C) 2018 Ispirata Srl
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
      event: {_event_type, event}
    } = simple_event

    with {:room_pid, [{pid, _}]} <-
           {:room_pid,
            Registry.lookup(Registry.AstarteRooms, {:parent_trigger_id, parent_trigger_id})},
         :ok <- Room.broadcast_event(pid, simple_trigger_id, device_id, event) do
      :ok
    else
      {:room_pid, []} ->
        # The room is dead, uninstall the trigger
        Logger.warn("dispatch: unexisting room for event #{inspect(simple_event)}")
        DataUpdaterPlant.delete_volatile_trigger(realm, device_id, simple_trigger_id)
        {:error, :no_room_for_event}

      {:error, :trigger_not_found} ->
        # The room has unwatched the trigger, uninstall it again
        Logger.warn("dispatch: trigger not found for event #{inspect(simple_event)}")
        DataUpdaterPlant.delete_volatile_trigger(realm, device_id, simple_trigger_id)
        {:error, :trigger_not_found}

      {:error, reason} ->
        # Dispatch error
        Logger.warn("dispatch: failed for event #{inspect(simple_event)} with reason #{reason}")
        {:error, :dispatch_error}
    end
  end
end
