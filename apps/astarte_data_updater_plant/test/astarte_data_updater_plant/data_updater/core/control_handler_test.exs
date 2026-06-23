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
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeResp
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HashOk
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.InitExchange
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SecretHash
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
    init_exchange = InitExchange.new()
    init_exchange_payload = InitExchange.cbor_encode(init_exchange)

    p256_init_exchange = InitExchange.new(:ecdh_p256_hkdf_sha256_aes_256_gcm)
    p256_init_exchange_payload = InitExchange.cbor_encode(p256_init_exchange)

    exchange_resp_payload = init_exchange |> ExchangeResp.new() |> ExchangeResp.cbor_encode()

    p256_exchange_resp_payload =
      p256_init_exchange |> ExchangeResp.new() |> ExchangeResp.cbor_encode()

    # InitExchange invalid payloads: [seq_num, key_type, cose_key, hkdf_salt, nonce]
    invalid_key_type_payload =
      CBOR.encode([
        0,
        99,
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(32)},
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(32)},
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(12)}
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
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(32)},
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(12)}
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
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(16)},
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(12)}
      ])

    wrong_nonce_payload =
      CBOR.encode([
        0,
        0,
        # valid 32-byte X25519 COSE_Key, so parsing proceeds to the nonce check
        %CBOR.Tag{
          tag: :bytes,
          value: CBOR.encode(%{1 => 1, -1 => 4, -2 => :crypto.strong_rand_bytes(32)})
        },
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(32)},
        # 8 bytes instead of the required 12
        %CBOR.Tag{tag: :bytes, value: :crypto.strong_rand_bytes(8)}
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
      wrong_nonce_payload: wrong_nonce_payload,
      invalid_exchange_resp_payload: invalid_exchange_resp_payload,
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

  describe "/keyAgreement" do
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
               ControlHandler.handle_control(state, "/keyAgreement", payload, 0)

      assert new_state.total_received_msgs == state.total_received_msgs + 1
      assert new_state.total_received_bytes == state.total_received_bytes + byte_size(payload)

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
               ControlHandler.handle_control(state, "/keyAgreement", payload, 0)

      assert new_state.total_received_msgs == state.total_received_msgs + 1
      assert new_state.total_received_bytes == state.total_received_bytes + byte_size(payload)

      assert {:established, %{alg: :ecdh_p256_hkdf_sha256_aes_256_gcm}} =
               new_state.encrypted_endpoints_key
    end

    test "discards the message if discard_messages is set", context do
      %{state: state} = context

      state = %{state | discard_messages: true}

      assert {:discard, _result, ^state} =
               ControlHandler.handle_control(state, "/keyAgreement", <<1>>, 0)
    end
  end

  describe "/keyAgreement - invalid payloads" do
    setup context do
      %{state: state} = context

      expect(Core.Device, :ask_clean_session, fn _state, _ts -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "key_agreement_error",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      :ok
    end

    test "discards a payload whose key_type integer is not a supported suite", context do
      %{state: state, invalid_key_type_payload: payload} = context

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards a payload with a wrong-size OKP public key", context do
      %{state: state, wrong_okp_key_payload: payload} = context

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards a payload with a wrong-size HKDF salt", context do
      %{state: state, wrong_hkdf_salt_payload: payload} = context

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards a payload with a wrong-size nonce", context do
      %{state: state, wrong_nonce_payload: payload} = context

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards a valid CBOR payload that is not a 5-element list", context do
      %{state: state} = context

      # CBOR-valid but wrong structure, hits the parse(_) fallback
      payload = CBOR.encode(%{"key_type" => 0})

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards a non-CBOR binary payload", context do
      %{state: state} = context

      payload = <<0xFF, 0xFE, 0x00, 0x01>>

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end
  end

  describe "send_init_exchange/1" do
    test "publishes a well-formed CBOR InitExchange to the device and returns the updated state",
         context do
      %{state: state} = context

      expect(VMQPlugin, :publish, fn topic, payload_bytes, qos ->
        encoded_device_id = Astarte.Core.Device.encode_device_id(state.device_id)

        assert topic == "#{state.realm}/#{encoded_device_id}/control/keyAgreement"
        assert qos == 2
        assert {:ok, _} = InitExchange.decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ok, new_state} = ControlHandler.send_init_exchange(state)

      assert {:handshake_started, %{key_type: :ecdh_x25519_hkdf_sha256_aes_256_gcm}} =
               new_state.encrypted_endpoints_key
    end

    test "returns {:error, :session_not_found} when the device has no active session",
         context do
      %{state: state} = context

      expect(VMQPlugin, :publish, fn _topic, _payload, _qos ->
        {:ok, %{local_matches: 0, remote_matches: 0}}
      end)

      assert {:error, :session_not_found} =
               ControlHandler.send_init_exchange(state)
    end

    test "returns {:error, reason} on VMQ publish failure", context do
      %{state: state} = context

      expect(VMQPlugin, :publish, fn _topic, _payload, _qos -> {:error, :transport_failure} end)

      assert {:error, :transport_failure} =
               ControlHandler.send_init_exchange(state)
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
      assert new_state.total_received_bytes == state.total_received_bytes + byte_size(payload)

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
      assert new_state.total_received_bytes == state.total_received_bytes + byte_size(payload)

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

        # Assert the HashOk payload correctly encoded the algorithm to 0
        assert {:ok, [0], ""} = CBOR.decode(payload_bytes)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ack, :ok, new_state} =
               ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)

      assert new_state.total_received_msgs == state.total_received_msgs + 1
      assert new_state.total_received_bytes == state.total_received_bytes + byte_size(payload)

      # The state should remain untouched
      assert {:established, _} = new_state.encrypted_endpoints_key
    end

    test "renegotiates if hashes mismatch", context do
      %{
        established_state: state,
        invalid_secret_hash_payload: payload
      } = context

      # Expect 1 publish (the InitExchange renegotiation fallback)
      expect(VMQPlugin, :publish, 1, fn _topic, _payload_bytes, _qos ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ack, :ok, new_state} =
               ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)

      # Ensure it correctly fell back and overwrote the :established state with a new handshake
      assert {:handshake_started, _} = new_state.encrypted_endpoints_key
      assert new_state.total_received_msgs == state.total_received_msgs + 1
    end

    test "renegotiates if no shared secret is established", context do
      %{state: state, valid_secret_hash_payload: payload} = context

      # state.encrypted_endpoints_key is :uninitialized by default here

      # Expect 1 publish (the InitExchange renegotiation fallback)
      expect(VMQPlugin, :publish, 1, fn _topic, _payload_bytes, _qos ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ack, :ok, new_state} =
               ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)

      # Ensure it started a new handshake
      assert {:handshake_started, _} = new_state.encrypted_endpoints_key
      assert new_state.total_received_msgs == state.total_received_msgs + 1
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

      # Mock publish failure
      expect(VMQPlugin, :publish, 1, fn _topic, _payload_bytes, _qos ->
        {:error, :transport_failure}
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

      expect(VMQPlugin, :publish, 1, fn _topic, _payload_bytes, _qos ->
        {:ok, %{local_matches: 0, remote_matches: 0}}
      end)

      assert {{:ack, :ok, ^state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)
               end)

      assert log =~ "Failed to process SecretHash: :session_not_found"
    end

    test "discards message and logs error if renegotiation fails", context do
      %{state: state, valid_secret_hash_payload: payload} = context

      expect(VMQPlugin, :publish, 1, fn _topic, _payload_bytes, _qos ->
        {:error, :transport_failure}
      end)

      assert {{:discard, :transport_failure, ^state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)
               end)

      assert log =~ "Failed to renegotiate key: :transport_failure"
    end

    test "discards message and logs error if renegotiation fails due to missing session",
         context do
      %{state: state, valid_secret_hash_payload: payload} = context

      expect(VMQPlugin, :publish, 1, fn _topic, _payload_bytes, _qos ->
        {:ok, %{local_matches: 0, remote_matches: 0}}
      end)

      assert {{:discard, :session_not_found, ^state}, log} =
               with_log(fn ->
                 ControlHandler.handle_control(state, "/keyAgreement/2", payload, 0)
               end)

      assert log =~ "Failed to renegotiate key: :session_not_found"
    end
  end

  describe "/keyAgreement/3" do
    setup do
      valid_hash_ok = %HashOk{key_type: :ecdh_x25519_hkdf_sha256_aes_256_gcm}
      valid_hash_ok_payload = HashOk.cbor_encode(valid_hash_ok)
      invalid_hash_ok_payload = CBOR.encode([99])

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
               established_state.total_received_bytes + byte_size(payload)
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

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/keyAgreement/3", payload, 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end
  end
end
