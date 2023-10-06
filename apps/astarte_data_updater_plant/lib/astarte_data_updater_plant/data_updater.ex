#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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
  alias Astarte.DataUpdaterPlant.AMQPDataConsumer
  alias Astarte.DataUpdaterPlant.DataUpdater.Server
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataAccess.Database
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

  # TODO remove this when all heartbeats will be moved to internal
  def handle_heartbeat(realm, encoded_device_id, tracking_id, timestamp) do
    message_tracker = get_message_tracker(realm, encoded_device_id)
    {message_id, delivery_tag} = tracking_id
    MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.cast({:handle_heartbeat, message_id, timestamp})
  end

  def handle_internal(
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
    |> GenServer.cast({:handle_internal, path, payload, message_id, timestamp})
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
    with :ok <- verify_device_exists(realm, encoded_device_id) do
      message_tracker = get_message_tracker(realm, encoded_device_id, offload_start: true)

      get_data_updater_process(realm, encoded_device_id, message_tracker, offload_start: true)
      |> GenServer.call(
        {:handle_install_volatile_trigger, object_id, object_type, parent_id, trigger_id,
         simple_trigger, trigger_target}
      )
    end
  end

  def handle_delete_volatile_trigger(realm, encoded_device_id, trigger_id) do
    with :ok <- verify_device_exists(realm, encoded_device_id) do
      message_tracker = get_message_tracker(realm, encoded_device_id, offload_start: true)

      get_data_updater_process(realm, encoded_device_id, message_tracker, offload_start: true)
      |> GenServer.call({:handle_delete_volatile_trigger, trigger_id})
    end
  end

  def dump_state(realm, encoded_device_id) do
    message_tracker = get_message_tracker(realm, encoded_device_id)

    get_data_updater_process(realm, encoded_device_id, message_tracker)
    |> GenServer.call({:dump_state})
  end

  def start_device_deletion(realm, encoded_device_id, timestamp) do
    with :ok <- verify_device_exists(realm, encoded_device_id) do
      message_tracker = get_message_tracker(realm, encoded_device_id, offload_start: true)

      get_data_updater_process(realm, encoded_device_id, message_tracker, offload_start: true)
      |> GenServer.call({:start_device_deletion, timestamp})
    end
  end

  def get_data_updater_process(realm, encoded_device_id, message_tracker, opts \\ []) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      case Registry.lookup(Registry.DataUpdater, {realm, device_id}) do
        [] ->
          if Keyword.get(opts, :offload_start) do
            # We pass through AMQPDataConsumer to start the process to make sure that
            # that start is serialized
            AMQPDataConsumer.start_data_updater(realm, encoded_device_id, message_tracker)
          else
            name = {:via, Registry, {Registry.DataUpdater, {realm, device_id}}}
            {:ok, pid} = Server.start(realm, device_id, message_tracker, name: name)
            pid
          end

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

  def get_message_tracker(realm, encoded_device_id, opts \\ []) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      device = {realm, device_id}

      case Registry.lookup(Registry.MessageTracker, device) do
        [] ->
          if Keyword.get(opts, :offload_start) do
            # We pass through AMQPDataConsumer to start the process to make sure that
            # that start is serialized and acknowledger is the right process
            AMQPDataConsumer.start_message_tracker(realm, encoded_device_id)
          else
            acknowledger = self()
            spawn_message_tracker(acknowledger, device)
          end

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

  defp verify_device_exists(realm_name, encoded_device_id) do
    with {:ok, decoded_device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, exists?} <- Queries.check_device_exists(client, decoded_device_id) do
      if exists? do
        :ok
      else
        _ =
          Logger.warn(
            "Device #{encoded_device_id} in realm #{realm_name} does not exist.",
            tag: "device_does_not_exist"
          )

        {:error, :device_does_not_exist}
      end
    end
  end
end
