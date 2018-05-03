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

defmodule Astarte.AppEngine.API.Rooms.RoomsSupervisor do
  use DynamicSupervisor

  alias Astarte.AppEngine.API.Rooms.Room

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_room(realm, room_name) do
    DynamicSupervisor.start_child(__MODULE__, {Room, realm: realm, room_name: room_name})
  end

  def room_started?(room_name) do
    case Registry.lookup(Registry.AstarteRooms, room_name) do
      [] ->
        false

      [{_pid, _value}] ->
        true
    end
  end

  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
