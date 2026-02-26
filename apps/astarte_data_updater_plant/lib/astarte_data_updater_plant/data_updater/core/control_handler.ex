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
  @moduledoc """
  This module is responsible for handling the control messages.
  """
  alias Astarte.DataUpdaterPlant.DataUpdater.Core

  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin
  alias Astarte.DataUpdaterPlant.TimeBasedActions

  require Logger

  def handle_control(%State{discard_messages: true} = state, _, _, _) do
    {:discard, :discard_messages, state}
  end

  def handle_control(state, "/producer/properties", <<0, 0, 0, 0>>, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    timestamp_ms = div(timestamp, 10_000)

    :ok = Core.Device.prune_device_properties(new_state, "", timestamp_ms)

    final_state = %{
      new_state
      | total_received_msgs: new_state.total_received_msgs + 1,
        total_received_bytes:
          new_state.total_received_bytes + byte_size(<<0, 0, 0, 0>>) +
            byte_size("/producer/properties")
    }

    {:ack, :ok, final_state}
  end

  def handle_control(state, "/producer/properties", payload, timestamp) do
    start_time = System.monotonic_time()

    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    timestamp_ms = div(timestamp, 10_000)

    # TODO: check payload size, to avoid annoying crashes

    decompression_start = System.monotonic_time()

    case decode_payload(state, payload) do
      {:ok, decoded_payload} ->
        # Track successful decompression
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :payload_decompression],
          %{
            duration: System.monotonic_time() - decompression_start,
            compressed_size: byte_size(payload),
            uncompressed_size: byte_size(decoded_payload)
          },
          %{realm: new_state.realm, result: "success"}
        )

        :ok = Core.Device.prune_device_properties(new_state, decoded_payload, timestamp_ms)

        # Track properties prune with payload
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :properties_prune],
          %{
            duration: System.monotonic_time() - start_time,
            payload_size: byte_size(payload)
          },
          %{realm: new_state.realm, prune_type: "with_payload"}
        )

        final_state = %{
          new_state
          | total_received_msgs: new_state.total_received_msgs + 1,
            total_received_bytes:
              new_state.total_received_bytes + byte_size(payload) +
                byte_size("/producer/properties")
        }

        {:ack, :ok, final_state}

      :error ->
        # Track failed decompression
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :payload_decompression],
          %{
            duration: System.monotonic_time() - decompression_start,
            compressed_size: byte_size(payload),
            uncompressed_size: 0
          },
          %{realm: new_state.realm, result: "failed"}
        )

        context = %{
          state: new_state,
          timestamp: timestamp,
          payload: payload
        }

        error = %{
          message: "Invalid purge_properties payload",
          logger_metadata: [tag: "purge_properties_error"],
          error_name: "purge_properties_error",
          error: :purge_properties_error
        }

        opts = [execute_error_triggers: false, update_stats: false]

        Core.Error.handle_error(context, error, opts)
    end
  end

  def handle_control(state, "/emptyCache", _payload, timestamp) do
    state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    with :ok <- send_control_consumer_properties(state, timestamp),
         {:ok, state} <- resend_all_properties(state, timestamp),
         :ok <- set_pending_empty_cache(state, timestamp) do
      :telemetry.execute(
        [:astarte, :data_updater_plant, :data_updater, :processed_empty_cache],
        %{},
        %{realm: state.realm}
      )

      {:ack, :ok, state}
    end
  end

  def handle_control(state, path, payload, timestamp) do
    # Track unexpected control messages
    :telemetry.execute(
      [:astarte, :data_updater_plant, :control_handler, :unexpected_control],
      %{payload_size: byte_size(payload)},
      %{realm: state.realm, control_path: path}
    )

    context = %{state: state, payload: payload, path: path, timestamp: timestamp}

    error = %{
      message:
        "Unexpected control on #{path}, base64-encoded payload: #{inspect(Base.encode64(payload))}",
      logger_metadata: [tag: "unexpected_control_message"],
      error_name: "unexpected_control_message",
      error: :unexpected_control_message,
      telemetry_name: [:astarte, :data_updater_plant, :data_updater, :discarded_control_message]
    }

    Core.Error.handle_error(context, error)
  end

  defp decode_payload(%State{capabilities: capabilities} = _state, payload) do
    case Map.get(capabilities, :purge_properties_compression_format) do
      :zlib ->
        <<_size_header::size(32), zlib_payload::binary>> = payload
        PayloadsDecoder.safe_inflate(zlib_payload)

      :plaintext ->
        {:ok, payload}
    end
  end

  defp send_control_consumer_properties(state, timestamp) do
    Logger.debug("Device introspection: #{inspect(state.introspection)}.")

    abs_paths_list =
      Enum.flat_map(state.introspection, fn {interface, _} ->
        descriptor = Map.get(state.interfaces, interface)

        case Core.Interface.maybe_handle_cache_miss(descriptor, interface, state) do
          {:ok, interface_descriptor, new_state} ->
            # Track successful interface loading
            :telemetry.execute(
              [:astarte, :data_updater_plant, :control_handler, :interface_loading],
              %{},
              %{realm: state.realm, interface: interface, result: "success"}
            )

            Core.Interface.gather_interface_property_paths(new_state.realm, interface_descriptor)

          {:error, :interface_loading_failed} ->
            # Track failed interface loading
            :telemetry.execute(
              [:astarte, :data_updater_plant, :control_handler, :interface_loading],
              %{},
              %{realm: state.realm, interface: interface, result: "failed"}
            )

            Logger.warning("Failed #{interface} interface loading.")
            []
        end
      end)

    compression_format = state.capabilities.purge_properties_compression_format

    # TODO: use the returned byte count in stats
    case send_consumer_properties_payload(
           state.realm,
           state.device_id,
           abs_paths_list,
           compression_format
         ) do
      {:ok, _bytes} -> :ok
      {:error, :session_not_found} -> session_not_found_error(state, timestamp)
      {:error, reason} -> generic_error(state, timestamp, reason)
    end
  end

  defp send_consumer_properties_payload(realm, device_id, abs_paths_list, compression_format) do
    topic = "#{realm}/#{Device.encode_device_id(device_id)}/control/consumer/properties"

    uncompressed_payload = Enum.join(abs_paths_list, ";")

    payload =
      case compression_format do
        :zlib ->
          payload_size = byte_size(uncompressed_payload)
          compressed_payload = :zlib.compress(uncompressed_payload)
          <<payload_size::unsigned-big-integer-size(32), compressed_payload::binary>>

        :plaintext ->
          uncompressed_payload
      end

    publish_start = System.monotonic_time()

    case VMQPlugin.publish(topic, payload, 2) do
      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote == 1 ->
        # Track successful publish
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :vmq_publish],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "success", matches: "single"}
        )

        {:ok, byte_size(topic) + byte_size(payload)}

      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote > 1 ->
        # Track multiple matches (unusual but successful)
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :vmq_publish],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "success", matches: "multiple"}
        )

        # This should not happen so we print a warning, but we consider it a successful publish
        Logger.warning(
          "Multiple match while publishing #{inspect(Base.encode64(payload))} on #{topic}.",
          tag: "publish_multiple_matches"
        )

        {:ok, byte_size(topic) + byte_size(payload)}

      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote == 0 ->
        # Track no matches (session not found)
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :vmq_publish],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "no_matches", matches: "none"}
        )

        {:error, :session_not_found}

      {:error, reason} ->
        # Track publish errors
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :vmq_publish],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "error", matches: "unknown"}
        )

        {:error, reason}
    end
  end

  defp set_pending_empty_cache(state, timestamp) do
    case Queries.set_pending_empty_cache(state.realm, state.device_id, false) do
      :ok -> :ok
      {:error, reason} -> generic_error(state, timestamp, reason)
    end
  end

  defp resend_all_properties(state, timestamp) do
    resend_start = System.monotonic_time()

    case Core.Device.resend_all_properties(state) do
      {:ok, new_state} ->
        # Track successful properties resend
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :properties_resend],
          %{duration: System.monotonic_time() - resend_start},
          %{realm: state.realm, result: "success"}
        )

        {:ok, new_state}

      {:error, :sending_properties_to_interface_failed} ->
        # Track interface send failure
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :properties_resend],
          %{duration: System.monotonic_time() - resend_start},
          %{realm: state.realm, result: "interface_failed"}
        )

        sending_properties_error(state, timestamp)

      {:error, reason} ->
        # Track other resend failures
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :properties_resend],
          %{duration: System.monotonic_time() - resend_start},
          %{realm: state.realm, result: "error"}
        )

        generic_error(state, timestamp, reason)
    end
  end

  defp session_not_found_error(state, timestamp) do
    context = %{
      state: state,
      timestamp: timestamp
    }

    error = %{
      message: "Cannot push data to device.",
      logger_metadata: [tag: "device_session_not_found"],
      error_name: "device_session_not_found",
      error: :device_session_not_found
    }

    opts = [update_stats: false]

    Core.Error.handle_error(context, error, opts)
  end

  defp sending_properties_error(state, timestamp) do
    context = %{state: state, timestamp: timestamp}

    error = %{
      message: "Cannot resend properties to interface",
      logger_metadata: [tag: "resend_interface_properties_failed"],
      error_name: "resend_interface_properties_failed",
      error: :resend_interface_properties_failed
    }

    opts = [update_stats: false]
    Core.Error.handle_error(context, error, opts)
  end

  defp generic_error(state, timestamp, reason) do
    context = %{
      state: state,
      timestamp: timestamp
    }

    error = %{
      message: "Unhandled error during emptyCache: #{inspect(reason)}",
      logger_metadata: [tag: "empty_cache_error"],
      extra_error_metadata: %{"reason" => inspect(reason)},
      error_name: "empty_cache_error",
      error: :empty_cache_error
    }

    opts = [update_stats: false]

    Core.Error.handle_error(context, error, opts)
  end
end
