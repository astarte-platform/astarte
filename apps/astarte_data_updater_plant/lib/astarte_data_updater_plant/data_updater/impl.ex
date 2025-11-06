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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Impl do
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.DataUpdaterPlant.DataUpdater.Cache
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.DataUpdaterPlant.TimeBasedActions
  require Logger

  def init_state(realm, device_id, message_tracker) do
    MessageTracker.register_data_updater(message_tracker)
    Process.monitor(message_tracker)

    new_state = %State{
      realm: realm,
      device_id: device_id,
      message_tracker: message_tracker,
      paths_cache: Cache.new(Config.paths_cache_size!())
    }

    encoded_device_id = Device.encode_device_id(device_id)
    Logger.metadata(realm: realm, device_id: encoded_device_id)
    Logger.info("Created device process.", tag: "device_process_created")

    device_status = Queries.get_device_status(new_state.realm, device_id)

    # TODO this could be a bang!
    {:ok, ttl} = Queries.get_datastream_maximum_storage_retention(new_state.realm)

    Map.merge(new_state, device_status)
    |> Map.put(:datastream_maximum_storage_retention, ttl)
  end

  def handle_deactivation(_state) do
    Logger.info("Deactivated device process.", tag: "device_process_deactivated")

    :ok
  end

  def handle_connection(%State{discard_messages: true} = state, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_connection(state, ip_address_string, message_id, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    timestamp_ms = div(timestamp, 10_000)

    ip_address_result =
      ip_address_string
      |> to_charlist()
      |> :inet.parse_address()

    ip_address =
      case ip_address_result do
        {:ok, ip_address} ->
          ip_address

        _ ->
          Logger.warning("Received invalid IP address #{ip_address_string}.")
          {0, 0, 0, 0}
      end

    Queries.set_device_connected!(
      new_state.realm,
      new_state.device_id,
      DateTime.from_unix!(timestamp_ms, :millisecond),
      ip_address
    )

    TriggersHandler.device_connected(
      new_state.realm,
      new_state.device_id,
      new_state.groups,
      ip_address_string,
      timestamp_ms
    )

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)
    Logger.info("Device connected.", ip_address: ip_address_string, tag: "device_connected")

    :telemetry.execute([:astarte, :data_updater_plant, :data_updater, :device_connection], %{}, %{
      realm: new_state.realm
    })

    %{new_state | connected: true, last_seen_message: timestamp}
  end

  def handle_internal(state, path, payload, message_id, timestamp) do
    Core.InternalHandler.handle_internal(state, path, payload, message_id, timestamp)
  end

  def start_device_deletion(state, timestamp) do
    # Device deletion is among time-based actions
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    {:ok, new_state}
  end

  def handle_disconnection(state, message_id, timestamp) do
    new_state =
      state
      |> TimeBasedActions.execute_time_based_actions(timestamp)
      |> Core.Device.set_device_disconnected(timestamp)

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)
    Logger.info("Device disconnected.", tag: "device_disconnected")

    %{new_state | last_seen_message: timestamp}
  end

  def handle_data(%State{discard_messages: true} = state, _, _, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_data(state, interface, path, payload, message_id, timestamp) do
    TimeBasedActions.execute_time_based_actions(state, timestamp)
    |> Core.DataHandler.handle_data(interface, path, payload, message_id, timestamp)
  end

  defdelegate handle_capabilities(state, capabilities, message_id, timestamp),
    to: Core.CapabilitiesHandler

  defdelegate handle_control(state, path, payload, message_id, timestamp), to: Core.ControlHandler

  defdelegate handle_introspection(state, payload, message_id, timestamp),
    to: Core.IntrospectionHandler
end
