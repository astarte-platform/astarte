#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlant.DataUpdater do
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.Server
  alias Astarte.DataUpdaterPlant.MessageTracker
  require Logger

  def handle_connection(
        realm,
        encoded_device_id,
        ip_address,
        tracking_id,
        timestamp
      ) do
    message_tracker = get_message_tracker(realm, encoded_device_id)
    {message_id, delivery_tag} = tracking_id
    MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.cast({:handle_connection, ip_address, message_id, timestamp})
  end

  def handle_disconnection(realm, encoded_device_id, tracking_id, timestamp) do
    message_tracker = get_message_tracker(realm, encoded_device_id)
    {message_id, delivery_tag} = tracking_id
    MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.cast({:handle_disconnection, message_id, timestamp})
  end

  def handle_heartbeat(realm, encoded_device_id, tracking_id, timestamp) do
    message_tracker = get_message_tracker(realm, encoded_device_id)
    {message_id, delivery_tag} = tracking_id
    MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.cast({:handle_heartbeat, message_id, timestamp})
  end

  def handle_data(
        realm,
        encoded_device_id,
        interface,
        path,
        payload,
        tracking_id,
        timestamp
      ) do
    message_tracker = get_message_tracker(realm, encoded_device_id)
    {message_id, delivery_tag} = tracking_id
    MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.cast({:handle_data, interface, path, payload, message_id, timestamp})
  end

  def handle_introspection(
        realm,
        encoded_device_id,
        payload,
        tracking_id,
        timestamp
      ) do
    message_tracker = get_message_tracker(realm, encoded_device_id)
    {message_id, delivery_tag} = tracking_id
    MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.cast({:handle_introspection, payload, message_id, timestamp})
  end

  def handle_control(
        realm,
        encoded_device_id,
        path,
        payload,
        tracking_id,
        timestamp
      ) do
    message_tracker = get_message_tracker(realm, encoded_device_id)
    {message_id, delivery_tag} = tracking_id
    MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.cast({:handle_control, path, payload, message_id, timestamp})
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
    message_tracker = get_message_tracker(realm, encoded_device_id)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.call(
      {:handle_install_volatile_trigger, object_id, object_type, parent_id, trigger_id,
       simple_trigger, trigger_target}
    )
  end

  def handle_delete_volatile_trigger(realm, encoded_device_id, trigger_id) do
    message_tracker = get_message_tracker(realm, encoded_device_id)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.call({:handle_delete_volatile_trigger, trigger_id})
  end

  def dump_state(realm, encoded_device_id) do
    message_tracker = get_message_tracker(realm, encoded_device_id)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.call({:dump_state})
  end

  defp get_data_updater_process(realm, encoded_device_id, message_tracker) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      case Registry.lookup(Registry.DataUpdater, {realm, device_id}) do
        [] ->
          name = {:via, Registry, {Registry.DataUpdater, {realm, device_id}}}
          {:ok, pid} = Server.start(realm, device_id, message_tracker, name: name)
          pid

        [{pid, nil}] ->
          pid
      end
    else
      {:error, :extended_id_not_allowed} ->
        # TODO: unrecoverable error, discard the message here
        Logger.info("Received unexpected extended device id: #{encoded_device_id}")

      {:error, :invalid_device_id} ->
        Logger.info("Received invalid device id: #{encoded_device_id}")
        # TODO: unrecoverable error, discard the message here
    end
  end

  defp get_message_tracker(realm, encoded_device_id) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      device = {realm, device_id}

      case Registry.lookup(Registry.MessageTracker, device) do
        [] ->
          acknowledger = self()
          spawn_message_tracker(acknowledger, device)

        [{pid, nil}] ->
          pid
      end
    else
      {:error, :extended_id_not_allowed} ->
        # TODO: unrecoverable error, discard the message here
        Logger.info("Received unexpected extended device id: #{encoded_device_id}")

      {:error, :invalid_device_id} ->
        Logger.info("Received invalid device id: #{encoded_device_id}")
        # TODO: unrecoverable error, discard the message here
    end
  end

  defp spawn_message_tracker(acknowledger, device) do
    name = {:via, Registry, {Registry.MessageTracker, device}}
    {:ok, pid} = MessageTracker.start_link(acknowledger: acknowledger, name: name)

    pid
  end
end
