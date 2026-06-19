#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HashOkTest do
  use ExUnit.Case, async: true

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HashOk

  describe "new/1" do
    test "accepts valid key_suite atoms" do
      msg_p256 = HashOk.new(:ecdh_p256_hkdf_sha256_aes_256_gcm)
      assert %HashOk{} = msg_p256
      assert msg_p256.key_type == :ecdh_p256_hkdf_sha256_aes_256_gcm

      msg_x25519 = HashOk.new(:ecdh_x25519_hkdf_sha256_aes_256_gcm)
      assert %HashOk{} = msg_x25519
      assert msg_x25519.key_type == :ecdh_x25519_hkdf_sha256_aes_256_gcm
    end
  end

  describe "encode/1" do
    test "returns a single-element list with the integer mapped from InitExchange" do
      # According to InitExchange.supported_key_suites(), x25519 is 0, p256 is 1
      msg_x25519 = HashOk.new(:ecdh_x25519_hkdf_sha256_aes_256_gcm)
      assert HashOk.encode(msg_x25519) == [0]

      msg_p256 = HashOk.new(:ecdh_p256_hkdf_sha256_aes_256_gcm)
      assert HashOk.encode(msg_p256) == [1]
    end
  end

  describe "cbor_encode/1" do
    test "encodes the struct into a valid CBOR binary" do
      msg = HashOk.new(:ecdh_p256_hkdf_sha256_aes_256_gcm)
      encoded = HashOk.cbor_encode(msg)

      assert is_binary(encoded)
      assert {:ok, [1], ""} = CBOR.decode(encoded)
    end
  end

  describe "cbor_decode/1" do
    test "successfully decodes a valid CBOR payload to the correct atom" do
      payload_x25519 = CBOR.encode([0])

      assert {:ok, %HashOk{key_type: :ecdh_x25519_hkdf_sha256_aes_256_gcm}} =
               HashOk.cbor_decode(payload_x25519)

      payload_p256 = CBOR.encode([1])

      assert {:ok, %HashOk{key_type: :ecdh_p256_hkdf_sha256_aes_256_gcm}} =
               HashOk.cbor_decode(payload_p256)
    end

    test "returns error for valid CBOR with unknown algorithm code" do
      unknown_alg_payload = CBOR.encode([99])
      assert {:error, :invalid_payload} = HashOk.cbor_decode(unknown_alg_payload)
    end

    test "returns error for valid CBOR with invalid inner structure" do
      invalid_payloads = [
        CBOR.encode("not a list"),
        CBOR.encode([]),
        CBOR.encode([-1]),
        CBOR.encode(["string"]),
        CBOR.encode([1, 2])
      ]

      for payload <- invalid_payloads do
        assert {:error, :invalid_payload} = HashOk.cbor_decode(payload)
      end
    end

    test "returns error for invalid malformed CBOR binary" do
      invalid_cbor = <<0xFF>>
      assert {:error, :invalid_payload} = HashOk.cbor_decode(invalid_cbor)
    end
  end
end
