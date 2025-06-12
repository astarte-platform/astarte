#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.ControlHandler do
  alias Astarte.DataUpdaterPlant.DataUpdater.Core

  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin

  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.TimeBasedActions
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries

  require Logger

  def handle_control(%State{discard_messages: true} = state, _, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_control(state, "/producer/properties", <<0, 0, 0, 0>>, message_id, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    timestamp_ms = div(timestamp, 10_000)

    :ok = Core.Device.prune_device_properties(new_state, "", timestamp_ms)

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)

    %{
      new_state
      | total_received_msgs: new_state.total_received_msgs + 1,
        total_received_bytes:
          new_state.total_received_bytes + byte_size(<<0, 0, 0, 0>>) +
            byte_size("/producer/properties")
    }
  end

  def handle_control(state, "/producer/properties", payload, message_id, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    timestamp_ms = div(timestamp, 10_000)

    # TODO: check payload size, to avoid annoying crashes

    <<_size_header::size(32), zlib_payload::binary>> = payload

    case PayloadsDecoder.safe_inflate(zlib_payload) do
      {:ok, decoded_payload} ->
        :ok = Core.Device.prune_device_properties(new_state, decoded_payload, timestamp_ms)
        MessageTracker.ack_delivery(new_state.message_tracker, message_id)

        %{
          new_state
          | total_received_msgs: new_state.total_received_msgs + 1,
            total_received_bytes:
              new_state.total_received_bytes + byte_size(payload) +
                byte_size("/producer/properties")
        }

      :error ->
        Logger.warning("Invalid purge_properties payload", tag: "purge_properties_error")

        {:ok, new_state} = Core.Device.ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        new_state
    end
  end

  def handle_control(state, "/emptyCache", _payload, message_id, timestamp) do
    state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    with :ok <- send_control_consumer_properties(state, message_id, timestamp),
         {:ok, state} <- resend_all_properties(state, message_id, timestamp),
         :ok <- set_pending_empty_cache(state, message_id, timestamp) do
      MessageTracker.ack_delivery(state.message_tracker, message_id)

      :telemetry.execute(
        [:astarte, :data_updater_plant, :data_updater, :processed_empty_cache],
        %{},
        %{realm: state.realm}
      )

      state
    end
  end

  def handle_control(state, path, payload, message_id, timestamp) do
    Logger.warning(
      "Unexpected control on #{path}, base64-encoded payload: #{inspect(Base.encode64(payload))}",
      tag: "unexpected_control_message"
    )

    {:ok, new_state} = Core.Device.ask_clean_session(state, timestamp)
    MessageTracker.discard(new_state.message_tracker, message_id)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :discarded_control_message],
      %{},
      %{realm: new_state.realm}
    )

    base64_payload = Base.encode64(payload)

    error_metadata = %{
      "path" => inspect(path),
      "base64_payload" => base64_payload
    }

    Core.Trigger.execute_device_error_triggers(
      new_state,
      "unexpected_control_message",
      error_metadata,
      timestamp
    )

    Core.DataHandler.update_stats(new_state, "", nil, path, payload)
  end

  defp send_control_consumer_properties(state, message_id, timestamp) do
    Logger.debug("Device introspection: #{inspect(state.introspection)}.")

    abs_paths_list =
      Enum.flat_map(state.introspection, fn {interface, _} ->
        descriptor = Map.get(state.interfaces, interface)

        case Core.Interface.maybe_handle_cache_miss(descriptor, interface, state) do
          {:ok, interface_descriptor, new_state} ->
            Core.Interface.gather_interface_property_paths(new_state.realm, interface_descriptor)

          {:error, :interface_loading_failed} ->
            Logger.warning("Failed #{interface} interface loading.")
            []
        end
      end)

    # TODO: use the returned byte count in stats
    case send_consumer_properties_payload(state.realm, state.device_id, abs_paths_list) do
      {:ok, _bytes} -> :ok
      {:error, :session_not_found} -> session_not_found_error(state, message_id, timestamp)
      {:error, reason} -> generic_error(state, message_id, timestamp, reason)
    end
  end

  defp send_consumer_properties_payload(realm, device_id, abs_paths_list) do
    topic = "#{realm}/#{Device.encode_device_id(device_id)}/control/consumer/properties"

    uncompressed_payload = Enum.join(abs_paths_list, ";")

    payload_size = byte_size(uncompressed_payload)
    compressed_payload = :zlib.compress(uncompressed_payload)

    payload = <<payload_size::unsigned-big-integer-size(32), compressed_payload::binary>>

    case VMQPlugin.publish(topic, payload, 2) do
      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote == 1 ->
        {:ok, byte_size(topic) + byte_size(payload)}

      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote > 1 ->
        # This should not happen so we print a warning, but we consider it a successful publish
        Logger.warning(
          "Multiple match while publishing #{inspect(Base.encode64(payload))} on #{topic}.",
          tag: "publish_multiple_matches"
        )

        {:ok, byte_size(topic) + byte_size(payload)}

      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote == 0 ->
        {:error, :session_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp set_pending_empty_cache(state, message_id, timestamp) do
    case Queries.set_pending_empty_cache(state.realm, state.device_id, false) do
      :ok -> :ok
      {:error, reason} -> generic_error(state, message_id, timestamp, reason)
    end
  end

  defp resend_all_properties(state, message_id, timestamp) do
    case Core.Device.resend_all_properties(state) do
      {:ok, new_state} ->
        {:ok, new_state}

      {:error, :sending_properties_to_interface_failed} ->
        sending_properties_error(state, message_id, timestamp)

      {:error, reason} ->
        generic_error(state, message_id, timestamp, reason)
    end
  end

  defp session_not_found_error(state, message_id, timestamp) do
    Logger.warning("Cannot push data to device.", tag: "device_session_not_found")

    {:ok, new_state} = Core.Device.ask_clean_session(state, timestamp)
    MessageTracker.discard(new_state.message_tracker, message_id)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :discarded_message],
      %{},
      %{realm: new_state.realm}
    )

    Core.Trigger.execute_device_error_triggers(
      new_state,
      "device_session_not_found",
      timestamp
    )

    new_state
  end

  defp sending_properties_error(state, message_id, timestamp) do
    Logger.warning("Cannot resend properties to interface",
      tag: "resend_interface_properties_failed"
    )

    {:ok, new_state} = Core.Device.ask_clean_session(state, timestamp)
    MessageTracker.discard(new_state.message_tracker, message_id)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :discarded_message],
      %{},
      %{realm: new_state.realm}
    )

    Core.Trigger.execute_device_error_triggers(
      new_state,
      "resend_interface_properties_failed",
      timestamp
    )

    new_state
  end

  defp generic_error(state, message_id, timestamp, reason) do
    Logger.warning("Unhandled error during emptyCache: #{inspect(reason)}",
      tag: "empty_cache_error"
    )

    {:ok, new_state} = Core.Device.ask_clean_session(state, timestamp)
    MessageTracker.discard(new_state.message_tracker, message_id)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :discarded_message],
      %{},
      %{realm: new_state.realm}
    )

    error_metadata = %{"reason" => inspect(reason)}

    Core.Trigger.execute_device_error_triggers(
      new_state,
      "empty_cache_error",
      error_metadata,
      timestamp
    )

    new_state
  end
end
