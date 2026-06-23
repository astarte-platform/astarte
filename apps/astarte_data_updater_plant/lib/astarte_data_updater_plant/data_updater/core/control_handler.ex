#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeResp
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HandshakeState
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HashOk
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.InitExchange
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SecretHash
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SharedSecret
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin
  alias Astarte.DataUpdaterPlant.TimeBasedActions

  require Logger

  @doc """
  Handles control messages published by the device on various control topics.

  ### Supported Paths
  * `/producer/properties` - Handles properties pruning (plaintext or zlib compressed).
  * `/emptyCache` - Triggers a cache empty and interface properties resend.
  * `/keyAgreement` - Handles the InitExchange protocol (Device to Astarte direction).
  * `/keyAgreement/1` - Receives an ExchangeResp sent by the device when Astarte previously initiated a key-agreement handshake.
  * `/keyAgreement/2` - Receives a SecretHash from the device to verify keys.
  * `/keyAgreement/3` - Receives a HashOk from the device confirming the key verification.
  """
  def handle_control(state, path, payload, timestamp)

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

  def handle_control(state, "/keyAgreement", payload, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    case InitExchange.decode(payload) do
      {:ok, init_exchange} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_init],
          %{payload_size: byte_size(payload)},
          %{realm: new_state.realm}
        )

        case perform_key_agreement(new_state, init_exchange, payload) do
          {:ok, final_state} ->
            {:ack, :ok, final_state}

          {:error, reason} ->
            Logger.error("[keyAgreement] State machine transition failed: #{inspect(reason)}")

            context = %{
              state: new_state,
              payload: payload,
              path: "/keyAgreement",
              timestamp: timestamp
            }

            error = %{
              message: "keyAgreement state machine transition failed: #{inspect(reason)}",
              logger_metadata: [tag: "key_agreement_transition_error"],
              error_name: "key_agreement_transition_error",
              error: :key_agreement_transition_error
            }

            Core.Error.handle_error(context, error)
        end

      {:error, reason} ->
        Logger.warning(
          "[keyAgreement] payload validation failed: #{inspect(reason)}",
          tag: "key_agreement_invalid_payload"
        )

        context = %{
          state: new_state,
          payload: payload,
          path: "/keyAgreement",
          timestamp: timestamp
        }

        error = %{
          message:
            "Invalid keyAgreement payload (#{inspect(reason)}): " <>
              inspect(Base.encode64(payload)),
          logger_metadata: [tag: "key_agreement_error"],
          error_name: "key_agreement_error",
          error: :key_agreement_error
        }

        Core.Error.handle_error(context, error)
    end
  end

  def handle_control(state, "/keyAgreement/1", payload, timestamp) do
    state
    |> TimeBasedActions.execute_time_based_actions(timestamp)
    |> process_key_agreement(payload, timestamp)
  end

  def handle_control(state, "/keyAgreement/2", payload, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    case SecretHash.cbor_decode(payload) do
      {:ok, %SecretHash{seq_num: seq_num} = secret_hash_msg} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_secret_hash],
          %{payload_size: byte_size(payload)},
          %{realm: new_state.realm}
        )

        process_secret_hash(new_state, seq_num, secret_hash_msg, payload, timestamp)

      {:error, reason} ->
        Logger.warning(
          "[keyAgreement/2] payload validation failed: #{inspect(reason)}",
          tag: "secret_hash_invalid_payload"
        )

        context = %{
          state: new_state,
          payload: payload,
          path: "/keyAgreement/2",
          timestamp: timestamp
        }

        error = %{
          message: "Invalid SecretHash payload: #{inspect(Base.encode64(payload))}",
          logger_metadata: [tag: "secret_hash_error"],
          error_name: "secret_hash_error",
          error: :secret_hash_error
        }

        Core.Error.handle_error(context, error)
    end
  end

  def handle_control(state, "/keyAgreement/3", payload, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    case HashOk.cbor_decode(payload) do
      {:ok, %HashOk{}} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_hash_ok],
          %{payload_size: byte_size(payload)},
          %{realm: new_state.realm}
        )

        # Execute the state transition
        case HandshakeState.transition(new_state.encrypted_endpoints_key, :secret_reconfirmed) do
          {:ok, new_key_state} ->
            final_state = %{
              new_state
              | encrypted_endpoints_key: new_key_state,
                total_received_msgs: new_state.total_received_msgs + 1,
                total_received_bytes: new_state.total_received_bytes + byte_size(payload)
            }

            {:ack, :ok, final_state}

          {:error, reason} ->
            Logger.error("[keyAgreement/3] State transition failed: #{inspect(reason)}")

            context = %{
              state: new_state,
              payload: payload,
              path: "/keyAgreement/3",
              timestamp: timestamp
            }

            error = %{
              message: "keyAgreement/3 state machine transition failed: #{inspect(reason)}",
              logger_metadata: [tag: "key_agreement_transition_error"],
              error_name: "key_agreement_transition_error",
              error: :key_agreement_transition_error
            }

            Core.Error.handle_error(context, error)
        end

      {:error, reason} ->
        Logger.warning(
          "[keyAgreement/3] payload validation failed: #{inspect(reason)}",
          tag: "hash_ok_invalid_payload"
        )

        context = %{
          state: new_state,
          payload: payload,
          path: "/keyAgreement/3",
          timestamp: timestamp
        }

        error = %{
          message: "Invalid HashOk payload: #{inspect(Base.encode64(payload))}",
          logger_metadata: [tag: "hash_ok_error"],
          error_name: "hash_ok_error",
          error: :hash_ok_error
        }

        Core.Error.handle_error(context, error)
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

  defp perform_key_agreement(new_state, init_exchange, payload) do
    with {:ok, state_after_receive} <-
           HandshakeState.transition(
             new_state.encrypted_endpoints_key,
             {:receive_init, init_exchange}
           ),
         {:ok, exchange_resp} <-
           send_exchange_resp(new_state.realm, new_state.device_id, init_exchange),
         {:ok, shared_secret} <-
           SharedSecret.derive(
             exchange_resp.public_key,
             init_exchange.public_key,
             init_exchange.hkdf_salt
           ),
         {:ok, established_key_state} <-
           HandshakeState.transition(
             state_after_receive,
             {:handshake_completed, shared_secret}
           ) do
      final_state = %{
        new_state
        | total_received_msgs: new_state.total_received_msgs + 1,
          total_received_bytes: new_state.total_received_bytes + byte_size(payload),
          encrypted_endpoints_key: established_key_state
      }

      {:ok, final_state}
    end
  end

  defp process_secret_hash(
         %{encrypted_endpoints_key: {:established, %{shared_secret: shared_secret, alg: alg}}} =
           state,
         _seq_num,
         secret_hash_msg,
         payload,
         _timestamp
       ) do
    state
    |> confirm_secret_hash(secret_hash_msg, shared_secret, alg)
    |> case do
      {:ok, new_key_state} ->
        final_state = %{
          state
          | encrypted_endpoints_key: new_key_state,
            total_received_msgs: state.total_received_msgs + 1,
            total_received_bytes: state.total_received_bytes + byte_size(payload)
        }

        {:ack, :ok, final_state}

      {:error, :hash_mismatch} ->
        Logger.warning("[keyAgreement/2] SecretHash mismatch. Renegotiating.")
        # TODO: implement ExchangeFailed message
        renegotiate_handshake(state, payload)

      {:error, reason} ->
        Logger.error("[keyAgreement/2] Failed to process SecretHash: #{inspect(reason)}")
        # TODO: implement ExchangeFailed message
        {:ack, :ok, state}
    end
  end

  defp process_secret_hash(state, _seq_num, _secret_hash_msg, payload, _timestamp) do
    Logger.warning("[keyAgreement/2] No shared secret established. Renegotiating.")
    # TODO: implement ExchangeFailed message
    renegotiate_handshake(state, payload)
  end

  defp confirm_secret_hash(state, secret_hash_msg, shared_secret, alg) do
    with :ok <- SecretHash.verify(secret_hash_msg, shared_secret),
         {:ok, new_key_state} <-
           HandshakeState.transition(state.encrypted_endpoints_key, :secret_reconfirmed) do
      case send_hash_ok(state.realm, state.device_id, alg) do
        :ok -> {:ok, new_key_state}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp renegotiate_handshake(state, payload) do
    case send_init_exchange(state) do
      {:ok, state_after_init} ->
        final_state = %{
          state_after_init
          | total_received_msgs: state.total_received_msgs + 1,
            total_received_bytes: state.total_received_bytes + byte_size(payload)
        }

        {:ack, :ok, final_state}

      {:error, reason} ->
        Logger.error("[keyAgreement/2] Failed to renegotiate key: #{inspect(reason)}")
        # TODO: implement ExchangeFailed message
        {:discard, reason, state}
    end
  end

  defp process_key_agreement(
         %{encrypted_endpoints_key: {:handshake_started, data}} = state,
         payload,
         timestamp
       ) do
    with {:ok, exchange_resp} <- decode_exchange_resp(state, payload, timestamp, data.key_type),
         {:ok, shared_secret} <- derive_shared_secret(state, data.init_exchange, exchange_resp),
         {:ok, new_key_state} <- transition_key_agreement(state, shared_secret) do
      :telemetry.execute(
        [:astarte, :data_updater_plant, :control_handler, :key_agreement_resp],
        %{payload_size: byte_size(payload)},
        %{realm: state.realm}
      )

      final_state = %{
        state
        | encrypted_endpoints_key: new_key_state,
          total_received_msgs: state.total_received_msgs + 1,
          total_received_bytes: state.total_received_bytes + byte_size(payload)
      }

      {:ack, :ok, final_state}
    else
      {:error, reason} ->
        # TODO: Implement failedexchange message
        Logger.warning("keyAgreement/1 failed, ignoring for now: #{inspect(reason)}")

        # Fallback
        {:ack, :ok, state}
    end
  end

  defp process_key_agreement(state, _payload, _timestamp) do
    Logger.warning("[keyAgreement/1] Unexpected response received.")
    {:ack, :ok, state}
  end

  defp decode_exchange_resp(_state, payload, _timestamp, expected_key_type) do
    case ExchangeResp.cbor_decode(payload, expected_key_type) do
      {:ok, exchange_resp} ->
        {:ok, exchange_resp}

      {:error, reason} ->
        # TODO : implement ExchangeFailed message
        {:error, reason}
    end
  end

  defp derive_shared_secret(_state, init_exchange, exchange_resp) do
    case SharedSecret.derive(
           init_exchange.public_key,
           exchange_resp.public_key,
           init_exchange.hkdf_salt
         ) do
      {:ok, shared_secret} ->
        {:ok, shared_secret}

      {:error, reason} ->
        Logger.error("[keyAgreement/1] Derivation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp transition_key_agreement(state, shared_secret) do
    case HandshakeState.transition(
           state.encrypted_endpoints_key,
           {:handshake_completed, shared_secret}
         ) do
      {:ok, new_key_state} ->
        {:ok, new_key_state}

      {:error, reason} ->
        Logger.error("[keyAgreement/1] State machine transition failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sends an `InitExchange` message from Astarte to a device to trigger
  a new key-agreement handshake

  Generates a fresh ephemeral X25519 key pair, a random HKDF
  salt, and a random AES-256-GCM nonce, CBOR-encodes the `InitExchange`
  struct, updates the state with the new handshake key type, and publishes
  it on: `<realm>/<device_id>/control/keyAgreement`
  """
  @spec send_init_exchange(State.t()) :: {:ok, State.t()} | {:error, term()}
  def send_init_exchange(state) do
    init_exchange = InitExchange.new()

    with :ok <- publish_init_exchange(state.realm, state.device_id, init_exchange),
         {:ok, new_key_state} <-
           HandshakeState.transition(
             state.encrypted_endpoints_key,
             {:initiate_handshake, init_exchange}
           ) do
      {:ok, %{state | encrypted_endpoints_key: new_key_state}}
    end
  end

  defp send_hash_ok(realm, device_id, alg) do
    topic = "#{realm}/#{Device.encode_device_id(device_id)}/control/keyAgreement/3"

    hash_ok = %HashOk{key_type: alg}
    payload = HashOk.cbor_encode(hash_ok)

    publish_start = System.monotonic_time()

    case VMQPlugin.publish(topic, payload, 2) do
      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote >= 1 ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_hash_ok_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "success"}
        )

        :ok

      {:ok, %{local_matches: 0, remote_matches: 0}} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_hash_ok_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "no_matches"}
        )

        {:error, :session_not_found}

      {:error, reason} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_hash_ok_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "error"}
        )

        {:error, reason}
    end
  end

  defp publish_init_exchange(realm, device_id, %InitExchange{} = init_exchange) do
    topic = "#{realm}/#{Device.encode_device_id(device_id)}/control/keyAgreement"
    payload = InitExchange.cbor_encode(init_exchange)

    publish_start = System.monotonic_time()

    case VMQPlugin.publish(topic, payload, 2) do
      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote >= 1 ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "success"}
        )

        :ok

      {:ok, %{local_matches: 0, remote_matches: 0}} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "no_matches"}
        )

        {:error, :session_not_found}

      {:error, reason} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "error"}
        )

        {:error, reason}
    end
  end

  @doc """
  Publishes an `ExchangeResp` message from Astarte to a device in response to a
  received `InitExchange` on:
  `<realm>/<device_id>/control/keyAgreement/1`
  """
  @spec send_exchange_resp(String.t(), binary(), InitExchange.t()) ::
          {:ok, ExchangeResp.t()} | {:error, term()}
  def send_exchange_resp(realm, device_id, %InitExchange{} = init_exchange) do
    exchange_resp = ExchangeResp.new(init_exchange)

    with :ok <- publish_exchange_resp(realm, device_id, exchange_resp) do
      {:ok, exchange_resp}
    end
  end

  defp publish_exchange_resp(realm, device_id, %ExchangeResp{} = exchange_resp) do
    topic = "#{realm}/#{Device.encode_device_id(device_id)}/control/keyAgreement/1"
    payload = ExchangeResp.cbor_encode(exchange_resp)

    publish_start = System.monotonic_time()

    case VMQPlugin.publish(topic, payload, 2) do
      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote >= 1 ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_resp_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "success"}
        )

        :ok

      {:ok, %{local_matches: 0, remote_matches: 0}} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_resp_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "no_matches"}
        )

        {:error, :session_not_found}

      {:error, reason} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_resp_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "error"}
        )

        {:error, reason}
    end
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
