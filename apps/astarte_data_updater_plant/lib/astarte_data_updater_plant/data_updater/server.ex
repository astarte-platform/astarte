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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Server do
  use GenServer
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl

  def start(realm, device_id, opts \\ []) do
    GenServer.start(__MODULE__, {realm, device_id}, opts)
  end

  def init({realm, device_id}) do
    new_state = Impl.init_state(realm, device_id)
    {:ok, new_state}
  end

  def handle_cast({:handle_connection, ip_address}, state) do
    new_state = Impl.handle_connection(state, ip_address)
    {:noreply, new_state}
  end

  def handle_cast({:handle_disconnection}, state) do
    new_state = Impl.handle_disconnection(state)
    {:noreply, new_state}
  end

  def handle_cast({:handle_message, interface, path, payload}, state) do
    new_state = Impl.handle_message(state, interface, path, payload)
    {:noreply, new_state}
  end

  def handle_cast({:handle_introspection, payload}, state) do
    new_state = Impl.handle_introspection(state, payload)
    {:noreply, new_state}
  end

  def handle_call({:dump_state}, _from, state) do
    IO.puts inspect state
    {:reply, :ok, state}
  end
end
