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

defmodule Astarte.DataUpdaterPlant.DataUpdater do
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.Server
  require Logger

  def handle_connection(realm, encoded_device_id, ip_address, delivery_tag, timestamp) do
    get_data_updater_process(realm, encoded_device_id)
    |> GenServer.cast({:handle_connection, ip_address, delivery_tag, timestamp})
  end

  def handle_disconnection(realm, encoded_device_id, delivery_tag, timestamp) do
    get_data_updater_process(realm, encoded_device_id)
    |> GenServer.cast({:handle_disconnection, delivery_tag, timestamp})
  end

  def handle_data(realm, encoded_device_id, interface, path, payload, delivery_tag, timestamp) do
    get_data_updater_process(realm, encoded_device_id)
    |> GenServer.cast({:handle_data, interface, path, payload, delivery_tag, timestamp})
  end

  def handle_introspection(realm, encoded_device_id, payload, delivery_tag, timestamp) do
    get_data_updater_process(realm, encoded_device_id)
    |> GenServer.cast({:handle_introspection, payload, delivery_tag, timestamp})
  end

  def handle_control(realm, encoded_device_id, path, payload, delivery_tag, timestamp) do
    get_data_updater_process(realm, encoded_device_id)
    |> GenServer.cast({:handle_control, path, payload, delivery_tag, timestamp})
  end

  def handle_install_volatile_trigger(
        realm,
        encoded_device_id,
        object_id,
        object_type,
        parent_id,
        trigger_id,
        simple_trigger,
        trigger_target
      ) do
    get_data_updater_process(realm, encoded_device_id)
    |> GenServer.call(
      {:handle_install_volatile_trigger, object_id, object_type, parent_id, trigger_id,
       simple_trigger, trigger_target}
    )
  end

  def handle_delete_volatile_trigger(realm, encoded_device_id, trigger_id) do
    get_data_updater_process(realm, encoded_device_id)
    |> GenServer.call({:handle_delete_volatile_trigger, trigger_id})
  end

  def dump_state(realm, encoded_device_id) do
    get_data_updater_process(realm, encoded_device_id)
    |> GenServer.call({:dump_state})
  end

  defp get_data_updater_process(realm, encoded_device_id) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id, allow_extended_id: true) do
      case Registry.lookup(Registry.DataUpdater, {realm, device_id}) do
        [] ->
          name = {:via, Registry, {Registry.DataUpdater, {realm, device_id}}}
          {:ok, pid} = Server.start(realm, device_id, name: name)
          pid

        [{pid, nil}] ->
          pid
      end
    else
      {:error, :invalid_device_id} ->
        Logger.info("Received invalid device id: #{encoded_device_id}")
        # TODO: unrecoverable error, discard the message here
    end
  end
end
