#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.MessageTracker
  require Logger

  def handle_connection(
        realm,
        encoded_device_id,
        ip_address,
        tracking_id,
        timestamp
      ) do
    {message_id, delivery_tag} = tracking_id

    with {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)
      GenServer.cast(data_updater, {:handle_connection, ip_address, message_id, timestamp})
    end
  end

  def handle_disconnection(realm, encoded_device_id, tracking_id, timestamp) do
    {message_id, delivery_tag} = tracking_id

    with {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

      GenServer.cast(data_updater, {:handle_disconnection, message_id, timestamp})
    end
  end

  # TODO remove this when all heartbeats will be moved to internal
  def handle_heartbeat(realm, encoded_device_id, tracking_id, timestamp) do
    {message_id, delivery_tag} = tracking_id

    with {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

      GenServer.cast(data_updater, {:handle_heartbeat, message_id, timestamp})
    end
  end

  def handle_internal(
        realm,
        encoded_device_id,
        path,
        payload,
        tracking_id,
        timestamp
      ) do
    {message_id, delivery_tag} = tracking_id

    with {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

      GenServer.cast(data_updater, {:handle_internal, path, payload, message_id, timestamp})
    end
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
    {message_id, delivery_tag} = tracking_id

    with {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

      GenServer.cast(
        data_updater,
        {:handle_data, interface, path, payload, message_id, timestamp}
      )
    end
  end

  def handle_introspection(
        realm,
        encoded_device_id,
        payload,
        tracking_id,
        timestamp
      ) do
    {message_id, delivery_tag} = tracking_id

    with {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)
      GenServer.cast(data_updater, {:handle_introspection, payload, message_id, timestamp})
    end
  end

  def handle_control(
        realm,
        encoded_device_id,
        path,
        payload,
        tracking_id,
        timestamp
      ) do
    {message_id, delivery_tag} = tracking_id

    with {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)
      GenServer.cast(data_updater, {:handle_control, path, payload, message_id, timestamp})
    end
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
    with :ok <- verify_device_exists(realm, encoded_device_id),
         {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      GenServer.call(
        data_updater,
        {:handle_install_volatile_trigger, object_id, object_type, parent_id, trigger_id,
         simple_trigger, trigger_target}
      )
    end
  end

  def handle_delete_volatile_trigger(realm, encoded_device_id, trigger_id) do
    with :ok <- verify_device_exists(realm, encoded_device_id),
         {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      GenServer.call(data_updater, {:handle_delete_volatile_trigger, trigger_id})
    end
  end

  def dump_state(realm, encoded_device_id) do
    with {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      GenServer.call(data_updater, {:dump_state})
    end
  end

  def start_device_deletion(realm, encoded_device_id, timestamp) do
    with :ok <- verify_device_exists(realm, encoded_device_id),
         {:ok, message_tracker} <- fetch_message_tracker(realm, encoded_device_id),
         {:ok, data_updater} <-
           fetch_data_updater_process(realm, encoded_device_id, message_tracker) do
      GenServer.call(data_updater, {:start_device_deletion, timestamp})
    end
  end

  def fetch_data_updater_process(realm, encoded_device_id, message_tracker, wait_start \\ false) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      sharding_key = {realm, device_id}

      args =
        if wait_start,
          do: {realm, device_id, message_tracker, :wait_start},
          else: {realm, device_id, message_tracker}

      case Horde.Registry.lookup(Registry.DataUpdater, {realm, device_id}) do
        [] ->
          case Horde.DynamicSupervisor.start_child(
                 Supervisor.DataUpdater,
                 {DataUpdater.Server, args}
               ) do
            {:ok, pid} ->
              {:ok, pid}

            {:ok, pid, _info} ->
              {:ok, pid}

            {:error, {:already_started, pid}} ->
              {:ok, pid}

            other ->
              _ =
                Logger.error(
                  "Could not start DataUpdater process for sharding_key #{inspect(sharding_key)}: #{inspect(other)}"
                )

              {:error, :data_updater_start_failed}
          end

        [{pid, _}] ->
          {:ok, pid}
      end
    else
      {:error, :extended_id_not_allowed} ->
        # TODO: unrecoverable error, discard the message here
        Logger.info("Received unexpected extended device id: #{encoded_device_id}")
        {:error, :extended_id_not_allowed}

      {:error, :invalid_device_id} ->
        Logger.info("Received invalid device id: #{encoded_device_id}")
        # TODO: unrecoverable error, discard the message here
        {:error, :invalid_device_id}
    end
  end

  def fetch_message_tracker(realm, encoded_device_id) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      # Consistent with verne algorithm
      queue_index =
        {realm, encoded_device_id}
        |> :erlang.phash2(Astarte.DataUpdaterPlant.Config.data_queue_total_count!())

      name = {:via, Horde.Registry, {Registry.MessageTracker, {realm, device_id}}}

      acknowledger =
        {:via, Horde.Registry, {Registry.AMQPDataConsumer, {:queue_index, queue_index}}}

      case Horde.Registry.lookup(Registry.MessageTracker, {realm, device_id}) do
        [] ->
          case Horde.DynamicSupervisor.start_child(
                 Supervisor.MessageTracker,
                 {MessageTracker.Server, [name: name, acknowledger: acknowledger]}
               ) do
            {:ok, pid} ->
              {:ok, pid}

            {:ok, pid, _info} ->
              {:ok, pid}

            {:error, {:already_started, pid}} ->
              {:ok, pid}

            other ->
              _ =
                Logger.error(
                  "Got error #{inspect(other)} while trying to setup a new message tracker for device #{inspect(device_id)} in realm #{inspect(realm)}. discarding the message."
                )

              {:error, :message_tracker_start_fail}
          end

        [{pid, _}] ->
          {:ok, pid}
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

  def verify_device_exists(realm_name, encoded_device_id) do
    with {:ok, decoded_device_id} <- Device.decode_device_id(encoded_device_id),
         # TODO this could be a bang!
         {:ok, exists?} <- Queries.check_device_exists(realm_name, decoded_device_id) do
      if exists? do
        :ok
      else
        _ =
          Logger.warning(
            "Device #{encoded_device_id} in realm #{realm_name} does not exist.",
            tag: "device_does_not_exist"
          )

        {:error, :device_does_not_exist}
      end
    end
  end

  @doc """
  Runs a `funciton` that needs a `dup` and `message_tracker` reference.

  Returns the function return value or `{:error, reason}` if one of these happen
  - The device could not be found (`device_id` in `realm`)
  - the `message_tracker` could not be found or started
  - the `data_updater` could not be found or started
  """
  def with_dup_and_message_tracker(realm, device_id, function) do
    with :ok <- verify_device_exists(realm, device_id),
         {:ok, message_tracker} <- fetch_message_tracker(realm, device_id),
         {:ok, dup} <- fetch_data_updater_process(realm, device_id, message_tracker) do
      function.(dup, message_tracker)
    end
  end
end
