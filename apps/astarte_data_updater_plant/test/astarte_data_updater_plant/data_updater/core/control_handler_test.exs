#
# This file is part of Astarte.
#
# Copyright 2025-2026 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.ControlHandlerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device

  use Astarte.Cases.DataUpdater

  use Mimic

  import ExUnit.CaptureLog

  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.ControlHandler
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeFailed
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeResp
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HandshakeState
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HashOk
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.InitExchange
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SecretHash
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SharedSecret
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin.ClientMock

  setup do
    Mox.verify_on_exit!()
  end

  setup do
    header = 0
    payload = System.unique_integer() |> to_string()
    decoded_payload = System.unique_integer() |> to_string()
    encoded_payload = <<header::size(32), payload::binary>>

    %{
      header: header,
      payload: payload,
      encoded_payload: encoded_payload,
      decoded_payload: decoded_payload
    }
  end

  setup_all do
    init_exchange = InitExchange.new(0)
    init_exchange_payload = InitExchange.cbor_encode(init_exchange)

    p256_init_exchange = InitExchange.new(0, :ecdh_p256_hkdf_sha256_aes_256_gcm)
    p256_init_exchange_payload = InitExchange.cbor_encode(p256_init_exchange)

    exchange_resp_payload = init_exchange |> ExchangeResp.new() |> ExchangeResp.cbor_encode()

    p256_exchange_resp_payload =
      p256_init_exchange |> ExchangeResp.new() |> ExchangeResp.cbor_encode()

    # InitExchange invalid payloads: [seq_num, key_type, cose_key, hkdf_salt]
    invalid_key_type_payload =
      CBOR.encode([
        0,
        99,
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(32)},
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(32)}
      ])

    wrong_okp_key_payload =
      CBOR.encode([
        0,
        0,
        # COSE_Key map with a 16-byte x coordinate instead of the required 32
        %CBOR.Tag{
          tag: :bytes,
          value: CBOR.encode(%{1 => 1, -1 => 4, -2 => :crypto.strong_rand_bytes(16)})
        },
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(32)}
      ])

    wrong_hkdf_salt_payload =
      CBOR.encode([
        0,
        0,
        # valid 32-byte X25519 COSE_Key, so parsing proceeds to the salt check
        %CBOR.Tag{
          tag: :bytes,
          value: CBOR.encode(%{1 => 1, -1 => 4, -2 => :crypto.strong_rand_bytes(32)})
        },
        # 16 bytes instead of the required 32
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(16)}
      ])

    # ExchangeResp invalid payload  [seq_num, cose_key] but seq_num is a string
    invalid_exchange_resp_payload =
      CBOR.encode([
        "not_an_integer",
        %CBOR.Tag{
          tag: :bytes,
          value: CBOR.encode(%{1 => 1, -1 => 4, -2 => :crypto.strong_rand_bytes(32)})
        }
      ])

    invalid_cose_key_exchange_resp_payload =
      CBOR.encode([
        0,
        %CBOR.Tag{
          tag: :bytes,
          value: CBOR.encode(%{1 => 1, -1 => 4, -2 => :crypto.strong_rand_bytes(16)})
        }
      ])

    # SecretHash payloads
    shared_secret = :crypto.strong_rand_bytes(32)
    valid_secret_hash = SecretHash.new(1, shared_secret)
    valid_secret_hash_payload = SecretHash.cbor_encode(valid_secret_hash)

    # Hash derived from a different random secret to simulate a mismatch
    invalid_secret_hash = %SecretHash{seq_num: 1, key_hash: :crypto.strong_rand_bytes(32)}
    invalid_secret_hash_payload = SecretHash.cbor_encode(invalid_secret_hash)

    %{
      init_exchange: init_exchange,
      init_exchange_payload: init_exchange_payload,
      p256_init_exchange: p256_init_exchange,
      p256_init_exchange_payload: p256_init_exchange_payload,
      exchange_resp_payload: exchange_resp_payload,
      p256_exchange_resp_payload: p256_exchange_resp_payload,
      invalid_key_type_payload: invalid_key_type_payload,
      wrong_okp_key_payload: wrong_okp_key_payload,
      wrong_hkdf_salt_payload: wrong_hkdf_salt_payload,
      invalid_exchange_resp_payload: invalid_exchange_resp_payload,
      invalid_cose_key_exchange_resp_payload: invalid_cose_key_exchange_resp_payload,
      shared_secret: shared_secret,
      valid_secret_hash_payload: valid_secret_hash_payload,
      invalid_secret_hash_payload: invalid_secret_hash_payload
    }
  end

  test "discards messages if discards_messages is enabled", context do
    %{state: state} = context
    state = %{state | discard_messages: true}

    {action, _result, new_state} =
      ControlHandler.handle_control(state, "/producer/properties", <<0, 0, 0, 0>>, 0)

    assert action == :discard
    assert new_state == state
  end

  describe "/emptyCache" do
    test "sets the pending empty cache and acks the message", context do
      %{state: state} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ack, _result, _new_state} =
               ControlHandler.handle_control(state, "/emptyCache", "", 0)
    end

    test "discrads the message if the device session is not found", context do
      %{state: state} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:ok, %{local_matches: 0, remote_matches: 0}}
      end)

      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "device_session_not_found",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/emptyCache", "", 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards the message if interface loading fails", context do
      %{state: state} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      expect(Core.Device, :resend_all_properties, fn _state ->
        {:error, :sending_properties_to_interface_failed}
      end)

      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "resend_interface_properties_failed",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/emptyCache", "", 0)

      {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards the message for other errors", context do
      %{state: state} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:error, :reason}
      end)

      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "empty_cache_error",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/emptyCache", "", 0)

      {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end
  end

  describe "/producer/properties" do
    test "prunes all device properties with payload = <<0, 0, 0, 0>>", context do
      %{state: state} = context

      expect(Core.Device, :prune_device_properties, fn _state, "", _timestamp -> :ok end)

      {action, _result, new_state} =
        ControlHandler.handle_control(state, "/producer/properties", <<0, 0, 0, 0>>, 0)

      assert action == :ack
      assert new_state.total_received_msgs > state.total_received_msgs
    end

    test "prunes the device properties with the deflated zlib payload", context do
      %{
        state: state,
        payload: payload,
        encoded_payload: encoded_payload,
        decoded_payload: decoded_payload
      } = context

      expect(Core.Device, :prune_device_properties, fn _state, ^decoded_payload, _timestamp ->
        :ok
      end)

      expect(PayloadsDecoder, :safe_inflate, fn ^payload -> {:ok, decoded_payload} end)

      {action, _result, new_state} =
        ControlHandler.handle_control(state, "/producer/properties", encoded_payload, 0)

      assert action == :ack
      assert new_state.total_received_msgs > state.total_received_msgs
    end

    test "asks a clean session for invalid zlib payload", context do
      %{
        state: state,
        payload: payload,
        encoded_payload: encoded_payload
      } = context

      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)
      expect(PayloadsDecoder, :safe_inflate, fn ^payload -> :error end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/producer/properties", encoded_payload, 0)

      {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end
  end

  test "unexpected messages are discarded and the device is asked a clean session", context do
    %{state: state} = context

    expect(Core.Device, :ask_clean_session, fn state, _timestamp -> {:ok, state} end)

    expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                            "unexpected_control_message",
                                                            _meta,
                                                            _ts ->
      :ok
    end)

    assert {{action, _result, new_state, {:continue, continue_arg}}, log} =
             with_log(fn ->
               ControlHandler.handle_control(state, "/invalid/path", <<>>, 0)
             end)

    {:ok, new_state} = Impl.handle_continue(continue_arg, new_state)

    assert action == :discard
    assert log =~ "Unexpected control"
    assert new_state.total_received_msgs > state.total_received_msgs
  end

  describe "/keyAgreement/0" do
    test "acks a valid CBOR InitExchange payload and increments message counters",
         context do
      %{state: state, init_exchange_payload: payload} = context

      expect(VMQPlugin, :publish, 1, fn topic, _payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(state.device_id)

        assert topic == "#{state.realm}/#{encoded_device_id}/control/keyAgreement/1"
        assert qos == 2

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ack, :ok, new_state} =
               ControlHandler.handle_control(state, "/keyAgreement/0", payload, 0)

      assert new_state.total_received_msgs == state.total_received_msgs + 1

      assert new_state.total_received_bytes ==
               state.total_received_bytes + byte_size(payload) + byte_size("/keyAgreement/0")

      assert {:established, %{alg: :ecdh_x25519_hkdf_sha256_aes_256_gcm}} =
               new_state.encrypted_endpoints_key
    end

    test "acks a valid CBOR InitExchange payload with a P-256 key", context do
      %{state: state, p256_init_exchange_payload: payload} = context

      expect(VMQPlugin, :publish, 1, fn topic, _payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(state.device_id)

        assert topic == "#{state.realm}/#{encoded_device_id}/control/keyAgreement/1"
        assert qos == 2

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ack, :ok, new_state} =
               ControlHandler.handle_control(state, "/keyAgreement/0", payload, 0)

      assert new_state.total_received_msgs == state.total_received_msgs + 1

      assert new_state.total_received_bytes ==
               state.total_received_bytes + byte_size(payload) + byte_size("/keyAgreement/0")

      assert {:established, %{alg: :ecdh_p256_hkdf_sha256_aes_256_gcm}} =
               new_state.encrypted_endpoints_key
    end

    test "discards the message if discard_messages is set", context do
      %{state: state} = context

      state = %{state | discard_messages: true}

      assert {:discard, _result, ^state} =
               ControlHandler.handle_control(state, "/keyAgreement/0", <<1>>, 0)
    end

    test "discards and asks a clean session when a handshake is already established",
         context do
      %{state: state, init_exchange_payload: payload} = context

      state = %{
        state
        | encrypted_endpoints_key:
            {:established,
             %{
               shared_secret: :crypto.strong_rand_bytes(32),
               alg: :ecdh_x25519_hkdf_sha256_aes_256_gcm
             }}
      }

      expect(Core.Device, :ask_clean_session, fn _state, _ts -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "key_agreement_transition_error",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      expect(VMQPlugin, :publish, fn topic, payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(state.device_id)

        assert topic == "#{state.realm}/#{encoded_device_id}/control/keyAgreement/4"
        assert qos == 2

        assert {:ok,
                %ExchangeFailed{reason: :unprocessable_entity, error_msg: "invalid transition"}} =
                 ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:discard, _result, new_state, {:continue, continue_arg}}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/0", payload, 0)
               end)

      assert log =~ "State machine transition failed: :unprocessable_entity - invalid transition"
      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end
  end

  describe "/keyAgreement/0 - invalid payloads" do
    setup context do
      %{state: state} = context

      expect(Core.Device, :ask_clean_session, fn _state, _ts -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "key_agreement_error",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      expect(VMQPlugin, :publish, fn topic, payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(state.device_id)

        assert topic == "#{state.realm}/#{encoded_device_id}/control/keyAgreement/4"
        assert qos == 2

        assert {:ok, %ExchangeFailed{seq_num: 0}} = ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      :ok
    end

    test "discards a payload whose key_type integer is not a supported suite", context do
      %{state: state, invalid_key_type_payload: payload} = context

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement/0", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards a payload with a wrong-size OKP public key", context do
      %{state: state, wrong_okp_key_payload: payload} = context

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement/0", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards a payload with a wrong-size HKDF salt", context do
      %{state: state, wrong_hkdf_salt_payload: payload} = context

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement/0", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards a valid CBOR payload that is not a 4-element list", context do
      %{state: state} = context

      # CBOR-valid but wrong structure, hits the parse(_) fallback
      payload = CBOR.encode(%{"key_type" => 0})

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement/0", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards a non-CBOR binary payload", context do
      %{state: state} = context

      payload = <<0xFF, 0xFE, 0x00, 0x01>>

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement/0", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end
  end

  describe "/keyAgreement/1" do
    test "acks a valid CBOR ExchangeResp payload and increments message counters",
         context do
      %{state: state, exchange_resp_payload: payload, init_exchange: init_exchange} = context

      # Inject the expected key agreement state for validation
      state = %{
        state
        | encrypted_endpoints_key:
            {:handshake_started,
             %{
               init_exchange: init_exchange,
               key_type: :ecdh_x25519_hkdf_sha256_aes_256_gcm
             }}
      }

      assert {:ack, :ok, new_state} =
               ControlHandler.handle_control(state, "/keyAgreement/1", payload, 0)

      assert new_state.total_received_msgs == state.total_received_msgs + 1

      assert new_state.total_received_bytes ==
               state.total_received_bytes + byte_size(payload) + byte_size("/keyAgreement/1")

      assert {:established, %{alg: :ecdh_x25519_hkdf_sha256_aes_256_gcm}} =
               new_state.encrypted_endpoints_key
    end

    test "acks a valid CBOR ExchangeResp payload with a P-256 key", context do
      %{state: state, p256_exchange_resp_payload: payload, p256_init_exchange: p256_init_exchange} =
        context

      # Inject the expected key agreement state for validation
      state = %{
        state
        | encrypted_endpoints_key:
            {:handshake_started,
             %{
               init_exchange: p256_init_exchange,
               key_type: :ecdh_p256_hkdf_sha256_aes_256_gcm
             }}
      }

      assert {:ack, :ok, new_state} =
               ControlHandler.handle_control(state, "/keyAgreement/1", payload, 0)

      assert new_state.total_received_msgs == state.total_received_msgs + 1

      assert new_state.total_received_bytes ==
               state.total_received_bytes + byte_size(payload) + byte_size("/keyAgreement/1")

      assert {:established, %{alg: :ecdh_p256_hkdf_sha256_aes_256_gcm}} =
               new_state.encrypted_endpoints_key
    end

    test "discards the message if discard_messages is set", context do
      %{state: state} = context

      state = %{state | discard_messages: true}

      assert {:discard, _result, ^state} =
               ControlHandler.handle_control(state, "/keyAgreement/1", <<1>>, 0)
    end
  end

  describe "/keyAgreement/1 - errors" do
    test "logs a warning and leaves the state untouched if no handshake was started",
         context do
      %{state: state} = context

      assert {{:ack, :ok, ^state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/1", <<1>>, 0)
               end)

      assert log =~ "Unexpected response received."
    end

    test "sends ExchangeFailed and transitions to :failed when the payload is invalid",
         context do
      %{
        state: state,
        invalid_exchange_resp_payload: payload,
        init_exchange: init_exchange
      } = context

      state = %{
        state
        | encrypted_endpoints_key:
            {:handshake_started,
             %{init_exchange: init_exchange, key_type: :ecdh_x25519_hkdf_sha256_aes_256_gcm}}
      }

      expect(VMQPlugin, :publish, fn topic, payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(state.device_id)

        assert topic == "#{state.realm}/#{encoded_device_id}/control/keyAgreement/4"
        assert qos == 2

        assert {:ok, %ExchangeFailed{reason: :invalid_argument, error_msg: "invalid payload"}} =
                 ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:ack, :ok, new_state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/1", payload, 0)
               end)

      assert log =~ "[keyAgreement/1] Processing failed: :invalid_argument - invalid payload"
      assert {:failed, :invalid_argument} = new_state.encrypted_endpoints_key
      assert new_state.total_received_msgs == state.total_received_msgs + 1

      assert new_state.total_received_bytes ==
               state.total_received_bytes + byte_size(payload) + byte_size("/keyAgreement/1")
    end

    test "sends ExchangeFailed and transitions to :failed when the COSE key is invalid",
         context do
      %{
        state: state,
        invalid_cose_key_exchange_resp_payload: payload,
        init_exchange: init_exchange
      } = context

      state = %{
        state
        | encrypted_endpoints_key:
            {:handshake_started,
             %{init_exchange: init_exchange, key_type: :ecdh_x25519_hkdf_sha256_aes_256_gcm}}
      }

      expect(VMQPlugin, :publish, fn _topic, payload_bytes, _qos ->
        assert {:ok, %ExchangeFailed{reason: :invalid_argument, error_msg: "invalid COSE key"}} =
                 ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:ack, :ok, new_state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/1", payload, 0)
               end)

      assert log =~ "[keyAgreement/1] Processing failed: :invalid_argument - invalid COSE key"
      assert {:failed, :invalid_argument} = new_state.encrypted_endpoints_key
    end

    test "sends ExchangeFailed and transitions to :failed when the key type does not match",
         context do
      # A valid X25519 ExchangeResp, sent while Astarte expects P-256
      %{
        state: state,
        exchange_resp_payload: payload,
        p256_init_exchange: p256_init_exchange
      } = context

      state = %{
        state
        | encrypted_endpoints_key:
            {:handshake_started,
             %{init_exchange: p256_init_exchange, key_type: :ecdh_p256_hkdf_sha256_aes_256_gcm}}
      }

      expect(VMQPlugin, :publish, fn _topic, payload_bytes, _qos ->
        assert {:ok,
                %ExchangeFailed{
                  reason: :unprocessable_entity,
                  error_msg: "unsupported key type"
                }} = ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:ack, :ok, new_state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/1", payload, 0)
               end)

      assert log =~
               "[keyAgreement/1] Processing failed: :unprocessable_entity - unsupported key type"

      assert {:failed, :unprocessable_entity} = new_state.encrypted_endpoints_key
    end

    test "sends ExchangeFailed and transitions to :failed when the keys are of mismatched suites",
         context do
      %{
        state: state,
        exchange_resp_payload: payload,
        p256_init_exchange: p256_init_exchange
      } = context

      state = %{
        state
        | encrypted_endpoints_key:
            {:handshake_started,
             %{init_exchange: p256_init_exchange, key_type: :ecdh_x25519_hkdf_sha256_aes_256_gcm}}
      }

      expect(VMQPlugin, :publish, fn _topic, payload_bytes, _qos ->
        assert {:ok,
                %ExchangeFailed{
                  reason: :unprocessable_entity,
                  error_msg: "unsupported or mismatched key"
                }} = ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:ack, :ok, new_state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/1", payload, 0)
               end)

      assert log =~
               "[keyAgreement/1] Processing failed: :unprocessable_entity - unsupported or mismatched key"

      assert {:failed, :unprocessable_entity} = new_state.encrypted_endpoints_key
    end

    test "sends ExchangeFailed with a generic message when derivation fails for an unexpected reason",
         context do
      %{
        state: state,
        exchange_resp_payload: payload,
        init_exchange: init_exchange
      } = context

      state = %{
        state
        | encrypted_endpoints_key:
            {:handshake_started,
             %{init_exchange: init_exchange, key_type: :ecdh_x25519_hkdf_sha256_aes_256_gcm}}
      }

      expect(SharedSecret, :derive, fn _my_key, _peer_key, _salt ->
        {:error, :unprocessable_entity, "key derivation failed"}
      end)

      expect(VMQPlugin, :publish, fn _topic, payload_bytes, _qos ->
        assert {:ok,
                %ExchangeFailed{
                  reason: :unprocessable_entity,
                  error_msg: "key derivation failed"
                }} = ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:ack, :ok, new_state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/1", payload, 0)
               end)

      assert log =~
               "[keyAgreement/1] Processing failed: :unprocessable_entity - key derivation failed"

      assert {:failed, :unprocessable_entity} = new_state.encrypted_endpoints_key
    end

    test "sends ExchangeFailed with a generic message when the handshake state transition unexpectedly fails",
         context do
      %{
        state: state,
        exchange_resp_payload: payload,
        init_exchange: init_exchange
      } = context

      state = %{
        state
        | encrypted_endpoints_key:
            {:handshake_started,
             %{init_exchange: init_exchange, key_type: :ecdh_x25519_hkdf_sha256_aes_256_gcm}}
      }

      expect(HandshakeState, :transition, fn _current_state, {:handshake_completed, _secret} ->
        {:error, :internal_server_error, "unexpected error"}
      end)

      expect(VMQPlugin, :publish, fn _topic, payload_bytes, _qos ->
        assert {:ok,
                %ExchangeFailed{
                  reason: :internal_server_error,
                  error_msg: "unexpected error"
                }} = ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:ack, :ok, new_state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/1", payload, 0)
               end)

      assert log =~
               "[keyAgreement/1] Processing failed: :internal_server_error - unexpected error"

      assert {:failed, :internal_server_error} = new_state.encrypted_endpoints_key
    end
  end

  describe "send_exchange_resp/3" do
    setup context do
      %{state: state} = context
      {:ok, realm: state.realm, device_id: state.device_id}
    end

    test "publishes a well-formed CBOR ExchangeResp (X25519) and returns the message",
         context do
      %{realm: realm, device_id: device_id, init_exchange: init_exchange} = context

      expect(VMQPlugin, :publish, fn topic, payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(device_id)

        assert topic == "#{realm}/#{encoded_device_id}/control/keyAgreement/1"
        assert qos == 2

        assert {:ok, decoded} =
                 ExchangeResp.cbor_decode(
                   payload_bytes,
                   :ecdh_x25519_hkdf_sha256_aes_256_gcm
                 )

        assert decoded.seq_num == init_exchange.seq_num

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ok, %ExchangeResp{} = msg} =
               ControlHandler.send_exchange_resp(realm, device_id, init_exchange)

      assert msg.seq_num == init_exchange.seq_num
      assert %COSE.Keys.OKP{} = msg.public_key
    end

    test "publishes a well-formed CBOR ExchangeResp (P-256) and returns the message",
         context do
      %{realm: realm, device_id: device_id, p256_init_exchange: init_exchange} = context

      expect(VMQPlugin, :publish, fn topic, payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(device_id)

        assert topic == "#{realm}/#{encoded_device_id}/control/keyAgreement/1"
        assert qos == 2

        assert {:ok, decoded} =
                 ExchangeResp.cbor_decode(
                   payload_bytes,
                   :ecdh_p256_hkdf_sha256_aes_256_gcm
                 )

        assert decoded.seq_num == init_exchange.seq_num

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ok, %ExchangeResp{} = msg} =
               ControlHandler.send_exchange_resp(realm, device_id, init_exchange)

      assert msg.seq_num == init_exchange.seq_num
      assert %COSE.Keys.ECC{} = msg.public_key
    end

    test "returns {:error, :session_not_found} when the device has no active session",
         context do
      %{realm: realm, device_id: device_id, init_exchange: init_exchange} = context

      expect(VMQPlugin, :publish, fn _topic, _payload, _qos ->
        {:ok, %{local_matches: 0, remote_matches: 0}}
      end)

      assert {:error, :session_not_found} =
               ControlHandler.send_exchange_resp(realm, device_id, init_exchange)
    end

    test "returns {:error, reason} on VMQ publish failure", context do
      %{realm: realm, device_id: device_id, init_exchange: init_exchange} = context

      expect(VMQPlugin, :publish, fn _topic, _payload, _qos -> {:error, :transport_failure} end)

      assert {:error, :transport_failure} =
               ControlHandler.send_exchange_resp(realm, device_id, init_exchange)
    end
  end

  describe "/keyAgreement/2" do
    setup context do
      established_key_state =
        {:established,
         %{
           shared_secret: context.shared_secret,
           alg: :ecdh_x25519_hkdf_sha256_aes_256_gcm
         }}

      established_state = %{context.state | encrypted_endpoints_key: established_key_state}

      %{established_state: established_state}
    end

    test "acks a valid SecretHash payload and sends HashOk when hashes match", context do
      %{
        established_state: state,
        valid_secret_hash_payload: payload
      } = context

      # Expect exactly 1 publish for the HashOk message
      expect(VMQPlugin, :publish, 1, fn topic, payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(state.device_id)

        assert topic == "#{state.realm}/#{encoded_device_id}/control/keyAgreement/3"
        assert qos == 2

        # Assert the HashOk payload carries the seq_num (1) of the associated SecretHash
        assert {:ok, %HashOk{seq_num: 1}} = HashOk.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ack, :ok, new_state} =
               ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)

      assert new_state.total_received_msgs == state.total_received_msgs + 1

      assert new_state.total_received_bytes ==
               state.total_received_bytes + byte_size(payload) + byte_size("/keyAgreement/2")

      # The state should remain untouched
      assert {:established, _} = new_state.encrypted_endpoints_key
    end

    test "discards payload and logs an error if the CBOR structure is invalid", context do
      %{state: state} = context

      # Corrupted/invalid payload
      payload = <<0xFF, 0xFE, 0x00>>

      expect(Core.Device, :ask_clean_session, fn _state, _ts -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "secret_hash_error",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "logs error and acks message if sending HashOk fails", context do
      %{
        established_state: state,
        valid_secret_hash_payload: payload
      } = context

      # 2 publishes: 1 HashOk (fails) + 1 ExchangeFailed (best-effort error notification)
      expect(VMQPlugin, :publish, fn _topic, _payload_bytes, _qos ->
        {:error, :transport_failure}
      end)

      expect(VMQPlugin, :publish, fn _topic, _payload_bytes, _qos ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:ack, :ok, ^state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)
               end)

      assert log =~ "Failed to process SecretHash: :transport_failure"
    end

    test "logs error and acks message if sending HashOk fails due to missing session", context do
      %{
        established_state: state,
        valid_secret_hash_payload: payload
      } = context

      # 2 publishes: 1 HashOk (session not found) + 1 ExchangeFailed (best-effort notification)
      expect(VMQPlugin, :publish, fn _topic, _payload_bytes, _qos ->
        {:ok, %{local_matches: 0, remote_matches: 0}}
      end)

      expect(VMQPlugin, :publish, fn _topic, _payload_bytes, _qos ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:ack, :ok, ^state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)
               end)

      assert log =~ "Failed to process SecretHash: :session_not_found"
    end

    test "sends ExchangeFailed with :hash_mismatch and acks when hashes do not match",
         context do
      %{
        established_state: state,
        invalid_secret_hash_payload: payload
      } = context

      expect(VMQPlugin, :publish, fn topic, payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(state.device_id)

        assert topic == "#{state.realm}/#{encoded_device_id}/control/keyAgreement/4"
        assert qos == 2

        assert {:ok,
                %ExchangeFailed{
                  reason: :hash_mismatch,
                  error_msg: "hash comparison failed"
                }} = ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:ack, :ok, ^state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)
               end)

      assert log =~ "[keyAgreement/2] SecretHash mismatch."
    end

    test "logs when the device is offline and cannot receive the ExchangeFailed notification",
         context do
      %{
        established_state: state,
        invalid_secret_hash_payload: payload
      } = context

      expect(VMQPlugin, :publish, fn _topic, _payload_bytes, _qos ->
        {:ok, %{local_matches: 0, remote_matches: 0}}
      end)

      assert {{:ack, :ok, ^state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)
               end)

      assert log =~ "Could not deliver ExchangeFailed"
      assert log =~ "device session not found"
    end

    test "logs when publishing the ExchangeFailed notification fails", context do
      %{
        established_state: state,
        invalid_secret_hash_payload: payload
      } = context

      expect(VMQPlugin, :publish, fn _topic, _payload_bytes, _qos ->
        {:error, :transport_failure}
      end)

      assert {{:ack, :ok, ^state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)
               end)

      assert log =~ "Could not deliver ExchangeFailed"
      assert log =~ ":transport_failure"
    end

    test "sends ExchangeFailed when no shared secret has been established yet", context do
      %{state: state, valid_secret_hash_payload: payload} = context

      expect(VMQPlugin, :publish, fn _topic, payload_bytes, _qos ->
        assert {:ok,
                %ExchangeFailed{
                  seq_num: _seq_num,
                  reason: :unprocessable_entity,
                  error_msg: "no shared secret established"
                }} = ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:ack, :ok, ^state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)
               end)

      assert log =~ "[keyAgreement/2] No shared secret established."
    end
  end

  describe "/keyAgreement/3" do
    setup do
      valid_hash_ok = %HashOk{seq_num: 1}
      valid_hash_ok_payload = HashOk.cbor_encode(valid_hash_ok)
      invalid_hash_ok_payload = CBOR.encode([-1])

      %{
        valid_hash_ok_payload: valid_hash_ok_payload,
        invalid_hash_ok_payload: invalid_hash_ok_payload
      }
    end

    test "acks a valid HashOk payload, updates state, and increments message counters", context do
      %{state: state, valid_hash_ok_payload: payload} = context

      # Inject the expected established key state before receiving HashOk
      established_state = %{
        state
        | encrypted_endpoints_key:
            {:established,
             %{
               shared_secret: :crypto.strong_rand_bytes(32),
               alg: :ecdh_x25519_hkdf_sha256_aes_256_gcm
             }}
      }

      assert {:ack, :ok, new_state} =
               ControlHandler.handle_control(established_state, "/keyAgreement/3", payload, 0)

      # Ensure it correctly transitioned/stayed in the established state
      assert {:established, _} = new_state.encrypted_endpoints_key
      assert new_state.total_received_msgs == established_state.total_received_msgs + 1

      assert new_state.total_received_bytes ==
               established_state.total_received_bytes + byte_size(payload) +
                 byte_size("/keyAgreement/3")
    end

    test "discards the message if discard_messages is set", context do
      %{state: state, valid_hash_ok_payload: payload} = context

      state = %{state | discard_messages: true}

      assert {:discard, :discard_messages, ^state} =
               ControlHandler.handle_control(state, "/keyAgreement/3", payload, 0)
    end

    test "discards payload and logs an error if the CBOR structure is invalid", context do
      %{state: state, invalid_hash_ok_payload: payload} = context

      expect(Core.Device, :ask_clean_session, fn _state, _ts -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "hash_ok_error",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      expect(VMQPlugin, :publish, fn topic, payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(state.device_id)

        assert topic == "#{state.realm}/#{encoded_device_id}/control/keyAgreement/4"
        assert qos == 2

        assert {:ok, %ExchangeFailed{seq_num: 0}} = ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement/3", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards and asks a clean session when no handshake has been established yet",
         context do
      %{state: state, valid_hash_ok_payload: payload} = context

      expect(Core.Device, :ask_clean_session, fn _state, _ts -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "key_agreement_transition_error",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      expect(VMQPlugin, :publish, fn topic, payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(state.device_id)

        assert topic == "#{state.realm}/#{encoded_device_id}/control/keyAgreement/4"
        assert qos == 2

        assert {:ok,
                %ExchangeFailed{
                  seq_num: 1,
                  reason: :unprocessable_entity,
                  error_msg: "invalid transition"
                }} = ExchangeFailed.cbor_decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {{:discard, _result, new_state, {:continue, continue_arg}}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/3", payload, 0)
               end)

      assert log =~
               "[keyAgreement/3] State transition failed: :unprocessable_entity - invalid transition"

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end
  end

  describe "/keyAgreement/4" do
    setup do
      {:ok, valid_exchange_failed} = ExchangeFailed.new(0, :hash_mismatch, "hash did not match")
      valid_exchange_failed_payload = ExchangeFailed.cbor_encode(valid_exchange_failed)

      # An invalid payload: 3 fields but error_code is a string instead of an integer
      invalid_exchange_failed_payload = CBOR.encode([0, "not_an_integer", "msg"])

      %{
        valid_exchange_failed: valid_exchange_failed,
        valid_exchange_failed_payload: valid_exchange_failed_payload,
        invalid_exchange_failed_payload: invalid_exchange_failed_payload
      }
    end

    test "acks a valid ExchangeFailed payload, updates state to failed, and increments counters",
         context do
      %{state: state, valid_exchange_failed_payload: payload} = context

      # Inject a handshake_started state so we can transition from it
      state = %{
        state
        | encrypted_endpoints_key: {:handshake_started, %{}}
      }

      assert {:ack, :ok, new_state} =
               ControlHandler.handle_control(state, "/keyAgreement/4", payload, 0)

      # Ensure it correctly transitioned to the failed state with the exact reason
      assert {:failed, :hash_mismatch} = new_state.encrypted_endpoints_key
      assert new_state.total_received_msgs == state.total_received_msgs + 1

      assert new_state.total_received_bytes ==
               state.total_received_bytes + byte_size(payload) + byte_size("/keyAgreement/4")
    end

    test "discards the message if discard_messages is set", context do
      %{state: state, valid_exchange_failed_payload: payload} = context

      state = %{state | discard_messages: true}

      assert {:discard, :discard_messages, ^state} =
               ControlHandler.handle_control(state, "/keyAgreement/4", payload, 0)
    end

    test "discards payload and logs an error if the CBOR structure is invalid", context do
      %{state: state, invalid_exchange_failed_payload: payload} = context

      expect(Core.Device, :ask_clean_session, fn _state, _ts -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "exchange_failed_error",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement/4", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end
  end
end
