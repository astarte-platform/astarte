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
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeFailed
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

  ### Lifecycle

  Call `handle_device_connection/1` once per MQTT Connect event before
  routing any control messages for that session.
  It resets session-scoped
  state (device sequence-number, stale handshake) and, when a
  shared secret is already established, sends a `SecretHash` to
  the device.

  ### Supported Paths
  * `/producer/properties` - Handles properties pruning (plaintext or zlib compressed).
  * `/emptyCache` - Triggers a cache empty and interface properties resend.
  * `/keyAgreement` - Handles the InitExchange protocol (Device to Astarte direction).
  * `/keyAgreement/1` - Receives an ExchangeResp sent by the device when Astarte previously initiated a key-agreement handshake.
  * `/keyAgreement/2` - Receives a SecretHash from the device to verify keys.
  * `/keyAgreement/3` - Receives a HashOk from the device confirming the key verification.
  * `/keyAgreement/4` - Receives an ExchangeFailed from the device signalling a key-agreement failure.
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

        with :ok <- validate_device_seq_num(init_exchange.seq_num, new_state.device_seq_num),
             {:ok, state_after_receive} <-
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
              encrypted_endpoints_key: established_key_state,
              device_seq_num: init_exchange.seq_num
          }

          {:ack, :ok, final_state}
        else
          {:error, :seq_num_replay} ->
            Logger.warning(
              "[keyAgreement] Replayed or out-of-order InitExchange seq_num=#{init_exchange.seq_num}, " <>
                "last_seen=#{new_state.device_seq_num}",
              tag: "key_agreement_seq_num_replay"
            )

            {:ack, :ok, new_state}

          {:error, reason} ->
            Logger.error("[keyAgreement] InitExchange handling failed: #{inspect(reason)}")
            {:ack, :ok, new_state}
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
        new_key_state =
          case HandshakeState.transition(new_state.encrypted_endpoints_key, :secret_reconfirmed) do
            {:ok, valid_state} ->
              valid_state

            {:error, reason} ->
              Logger.warning("[keyAgreement/3] State transition failed: #{inspect(reason)}")
              new_state.encrypted_endpoints_key
          end

        final_state = %{
          new_state
          | encrypted_endpoints_key: new_key_state,
            total_received_msgs: new_state.total_received_msgs + 1,
            total_received_bytes: new_state.total_received_bytes + byte_size(payload)
        }

        {:ack, :ok, final_state}

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

  def handle_control(state, "/keyAgreement/4", payload, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    case ExchangeFailed.cbor_decode(payload) do
      {:ok, %ExchangeFailed{reason: reason}} ->
        Logger.warning(
          "[keyAgreement/4] Device signalled ExchangeFailed: #{inspect(reason)}",
          tag: "key_agreement_device_failed"
        )

        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_device_failed],
          %{payload_size: byte_size(payload)},
          %{realm: new_state.realm, reason: reason}
        )

        # FIX: Safely handle the state transition instead of a naked match
        new_key_state =
          case HandshakeState.transition(new_state.encrypted_endpoints_key, {:error, reason}) do
            {:ok, failed_state} ->
              failed_state

            {:error, transition_reason} ->
              Logger.warning(
                "[keyAgreement/4] State transition failed: #{inspect(transition_reason)}"
              )

              {:failed, reason}
          end

        final_state = %{
          new_state
          | encrypted_endpoints_key: new_key_state,
            total_received_msgs: new_state.total_received_msgs + 1,
            total_received_bytes: new_state.total_received_bytes + byte_size(payload)
        }

        {:ack, :ok, final_state}

      {:error, decode_reason} ->
        Logger.warning(
          "[keyAgreement/4] payload validation failed: #{inspect(decode_reason)}",
          tag: "exchange_failed_invalid_payload"
        )

        context = %{
          state: new_state,
          payload: payload,
          path: "/keyAgreement/4",
          timestamp: timestamp
        }

        error = %{
          message: "Invalid ExchangeFailed payload: #{inspect(Base.encode64(payload))}",
          logger_metadata: [tag: "exchange_failed_error"],
          error_name: "exchange_failed_error",
          error: :exchange_failed_error
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

  defp process_secret_hash(
         %{encrypted_endpoints_key: {:established, %{shared_secret: shared_secret, alg: alg}}} =
           state,
         seq_num,
         secret_hash_msg,
         payload,
         _timestamp
       ) do
    with :ok <- validate_device_seq_num(seq_num, state.device_seq_num),
         :ok <- SecretHash.verify(secret_hash_msg, shared_secret),
         {:ok, new_key_state} <-
           HandshakeState.transition(state.encrypted_endpoints_key, :secret_reconfirmed),
         :ok <- send_hash_ok(state.realm, state.device_id, alg) do
      final_state = %{
        state
        | encrypted_endpoints_key: new_key_state,
          total_received_msgs: state.total_received_msgs + 1,
          total_received_bytes: state.total_received_bytes + byte_size(payload),
          device_seq_num: seq_num
      }

      {:ack, :ok, final_state}
    else
      {:error, :seq_num_replay} ->
        Logger.warning(
          "[keyAgreement/2] Replayed or out-of-order SecretHash seq_num=#{seq_num}, " <>
            "last_seen=#{state.device_seq_num}",
          tag: "secret_hash_seq_num_replay"
        )

        {:ack, :ok, state}

      {:error, :hash_mismatch} ->
        Logger.warning("[keyAgreement/2] SecretHash mismatch. Renegotiating.")
        renegotiate_handshake(state, payload)

      {:error, reason} ->
        # HashOk delivery failure
        Logger.warning(
          "[keyAgreement/2] Failed to process SecretHash: #{inspect(reason)}",
          tag: "secret_hash_send_failed"
        )

        {:ack, :ok, state}
    end
  end

  # Fallback: no shared secret established — renegotiate immediately.
  # No ExchangeFailed is sent; the InitExchange itself is the signal to the device.
  defp process_secret_hash(state, _seq_num, _secret_hash_msg, payload, _timestamp) do
    Logger.warning("[keyAgreement/2] No shared secret established. Renegotiating.")
    renegotiate_handshake(state, payload)
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
        {:discard, reason, state}
    end
  end

  defp process_key_agreement(
         %{encrypted_endpoints_key: {:handshake_started, data}} = state,
         payload,
         timestamp
       ) do
    with {:ok, exchange_resp} <- decode_exchange_resp(state, payload, timestamp, data.key_type),
         :ok <- validate_seq_num(exchange_resp.seq_num, data.init_exchange.seq_num),
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
      {:error, :seq_num_mismatch} ->
        Logger.warning(
          "keyAgreement/1 failed, ignoring for now: :seq_num_mismatch",
          tag: "key_agreement_seq_num_mismatch"
        )

        {:ack, :ok, state}

      {:error, reason} ->
        Logger.warning("[keyAgreement/1] Processing failed: #{inspect(reason)}")

        failed_reason =
          case reason do
            :invalid_payload -> :invalid_payload
            :key_type_mismatch -> :unspecified
            _ -> :unspecified
          end

        :ok = send_exchange_failed(state.realm, state.device_id, failed_reason)

        {:ok, failed_key_state} =
          HandshakeState.transition(state.encrypted_endpoints_key, {:error, failed_reason})

        final_state = %{
          state
          | encrypted_endpoints_key: failed_key_state,
            total_received_msgs: state.total_received_msgs + 1,
            total_received_bytes: state.total_received_bytes + byte_size(payload)
        }

        {:ack, :ok, final_state}
    end
  end

  defp process_key_agreement(state, _payload, _timestamp) do
    Logger.warning("[keyAgreement/1] Unexpected response received.")
    {:ack, :ok, state}
  end

  @spec validate_seq_num(non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, :seq_num_mismatch}
  defp validate_seq_num(received_seq, expected_seq) when received_seq == expected_seq, do: :ok
  defp validate_seq_num(_received_seq, _expected_seq), do: {:error, :seq_num_mismatch}

  # Validates that a seq_num received FROM the device is strictly greater than the last
  # one we have seen from it
  defp validate_device_seq_num(_seq_num, nil), do: :ok
  defp validate_device_seq_num(seq_num, last_seen) when seq_num > last_seen, do: :ok
  defp validate_device_seq_num(_seq_num, _last_seen), do: {:error, :seq_num_replay}

  @spec decode_exchange_resp(State.t(), binary(), integer(), atom()) ::
          {:ok, ExchangeResp.t()} | {:error, :invalid_payload | :key_type_mismatch}
  defp decode_exchange_resp(_state, payload, _timestamp, expected_key_type) do
    case ExchangeResp.cbor_decode(payload, expected_key_type) do
      {:ok, exchange_resp} ->
        {:ok, exchange_resp}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp derive_shared_secret(_state, init_exchange, exchange_resp) do
    SharedSecret.derive(
      init_exchange.public_key,
      exchange_resp.public_key,
      init_exchange.hkdf_salt
    )
  end

  defp transition_key_agreement(state, shared_secret) do
    HandshakeState.transition(
      state.encrypted_endpoints_key,
      {:handshake_completed, shared_secret}
    )
  end

  @doc """
  Performs key-agreement state actions on MQTT Connect.

  * **`device_seq_num`**: Always reset to `nil` (counters are session-scoped).
  * **`{:handshake_started, _}`**: Always reset to `:uninitialized` (mid-handshake states cannot carry over).
  * **`{:established, _}`**: Triggers a proactive `SecretHash` message to confirm the device still holds the shared secret before allowing encrypted traffic.
  * **`:uninitialized` / `{:failed, _}`**: No action taken; waits for the device to initiate a fresh handshake.
  """
  @spec handle_device_connection(State.t()) :: {:ok, State.t()} | {:error, term()}
  def handle_device_connection(state) do
    # reset the device-side sequence number on a new MQTT
    # the counter is session-scoped and must not carry over.
    session_state = %{state | device_seq_num: nil}

    case session_state.encrypted_endpoints_key do
      {:established, %{shared_secret: shared_secret}} ->
        # A shared secret is present. Send SecretHash so the
        # device can confirm it still holds the same key
        case send_secret_hash(session_state, shared_secret) do
          {:ok, new_state} ->
            Logger.debug(
              "[handle_device_connection] Sent SecretHash to verify existing key",
              realm: state.realm,
              tag: "key_agreement_secret_hash_on_connect"
            )

            {:ok, new_state}

          {:error, reason} ->
            Logger.warning(
              "[handle_device_connection] Failed to send SecretHash: #{inspect(reason)}. " <>
                "Resetting key state.",
              tag: "key_agreement_secret_hash_connect_failed"
            )

            # Publishing failed
            reset_state = %{
              session_state
              | encrypted_endpoints_key: :uninitialized
            }

            {:error, {reason, reset_state}}
        end

      {:handshake_started, _} ->
        # A previous session started a handshake that never completed.
        # The device will have discarded its ephemeral keys on disconnect,
        # so the stored InitExchange is unusable. Reset and wait for the
        # device to re-initiate.
        Logger.debug(
          "[handle_device_connection] Resetting stale handshake_started state on reconnect",
          realm: state.realm,
          tag: "key_agreement_stale_handshake_reset"
        )

        {:ok, %{session_state | encrypted_endpoints_key: :uninitialized}}

      _other ->
        # :uninitialized or {:failed, _}, wait for device.
        {:ok, session_state}
    end
  end

  @doc """
  Sends an `InitExchange` message from Astarte to a device to trigger
  a new key-agreement handshake

  Generates a fresh ephemeral key pair, a random HKDF
  salt, CBOR-encodes the `InitExchange`
  struct, updates the state with the new handshake key type, and publishes
  it on: `<realm>/<device_id>/control/keyAgreement`
  """
  @spec send_init_exchange(State.t()) :: {:ok, State.t()} | {:error, term()}
  def send_init_exchange(state) do
    seq_num = state.key_agreement_seq_num
    init_exchange = InitExchange.new(seq_num)

    with :ok <- publish_init_exchange(state.realm, state.device_id, init_exchange),
         {:ok, new_key_state} <-
           HandshakeState.transition(
             state.encrypted_endpoints_key,
             {:initiate_handshake, init_exchange}
           ) do
      {:ok,
       %{
         state
         | encrypted_endpoints_key: new_key_state,
           key_agreement_seq_num: seq_num + 1
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Sends a `SecretHash` message from Astarte to a device to verify that both
  sides share the same derived symmetric key.

  This is used in the key-already-present flow:
  when Astarte reconnects and already holds a shared secret, it sends a
  `SecretHash` instead of a full `InitExchange`, allowing the device to confirm
  the key is still valid with a `HashOk` reply.

  Published on: `<realm>/<device_id>/control/keyAgreement/2`
  """
  @spec send_secret_hash(State.t(), binary()) :: {:ok, State.t()} | {:error, term()}
  def send_secret_hash(%{encrypted_endpoints_key: {:established, _}} = state, shared_secret) do
    seq_num = state.key_agreement_seq_num
    secret_hash = SecretHash.new(seq_num, shared_secret)
    topic = "#{state.realm}/#{Device.encode_device_id(state.device_id)}/control/keyAgreement/2"
    payload = SecretHash.cbor_encode(secret_hash)

    publish_start = System.monotonic_time()

    case VMQPlugin.publish(topic, payload, 2) do
      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote >= 1 ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_secret_hash_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: state.realm, result: "success"}
        )

        {:ok, %{state | key_agreement_seq_num: seq_num + 1}}

      {:ok, %{local_matches: 0, remote_matches: 0}} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_secret_hash_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: state.realm, result: "no_matches"}
        )

        {:error, :session_not_found}

      {:error, reason} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_secret_hash_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: state.realm, result: "error"}
        )

        {:error, reason}
    end
  end

  defp send_hash_ok(realm, device_id, alg) do
    topic = "#{realm}/#{Device.encode_device_id(device_id)}/control/keyAgreement/3"

    hash_ok = HashOk.new(alg)
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

  defp send_exchange_failed(realm, device_id, reason) do
    topic = "#{realm}/#{Device.encode_device_id(device_id)}/control/keyAgreement/4"

    exchange_failed = ExchangeFailed.new(reason)
    payload = ExchangeFailed.cbor_encode(exchange_failed)

    publish_start = System.monotonic_time()

    case VMQPlugin.publish(topic, payload, 2) do
      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote >= 1 ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_exchange_failed_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "success", reason: reason}
        )

        :ok

      {:ok, %{local_matches: 0, remote_matches: 0}} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_exchange_failed_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "no_matches", reason: reason}
        )

        # Device is offline; best-effort only — log and continue.
        Logger.warning(
          "[keyAgreement/4] Could not deliver ExchangeFailed (#{inspect(reason)}): device session not found",
          tag: "exchange_failed_no_session"
        )

        :ok

      {:error, publish_reason} ->
        :telemetry.execute(
          [:astarte, :data_updater_plant, :control_handler, :key_agreement_exchange_failed_send],
          %{
            duration: System.monotonic_time() - publish_start,
            payload_size: byte_size(payload)
          },
          %{realm: realm, result: "error", reason: reason}
        )

        Logger.warning(
          "[keyAgreement/4] Could not deliver ExchangeFailed (#{inspect(reason)}): #{inspect(publish_reason)}",
          tag: "exchange_failed_publish_error"
        )

        # Still best-effort — the caller proceeds regardless.
        :ok
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
