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

  def dispatch(serialized_simple_event) do
    %SimpleEvent{
      simple_trigger_id: simple_trigger_id,
      parent_trigger_id: parent_trigger_id,
      realm: realm,
      device_id: device_id,
      event: {_event_type, event}
    } = SimpleEvent.decode(serialized_simple_event)

    with [{pid, _}] <- Registry.lookup(RoomsRegistry, {:parent_trigger_id, parent_trigger_id}) do
      Room.broadcast_event(pid, device_id, event)
    else
      [] ->
        # The room is dead, uninstall the trigger
        DataUpdaterPlant.delete_volatile_trigger(realm, device_id, simple_trigger_id)
    end
  end
end
