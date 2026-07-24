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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SharedSecretTest do
  use ExUnit.Case, async: true

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeResp
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.InitExchange
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SharedSecret
  alias COSE.Keys.ECC

  defp handshake_pair(key_type) do
    init_exchange = InitExchange.new(0, key_type)
    exchange_resp = ExchangeResp.new(init_exchange)
    {init_exchange, exchange_resp}
  end

  describe "derive/2 with X25519" do
    test "produces a 32-byte AES-256-GCM key" do
      {init_exchange, exchange_resp} = handshake_pair(:ecdh_x25519_hkdf_sha256_aes_256_gcm)

      assert {:ok, symmetric_key} = SharedSecret.derive(init_exchange, exchange_resp)
      assert symmetric_key.alg == :aes_256_gcm
      assert byte_size(symmetric_key.k) == 32
    end

    test "different handshakes produce different keys" do
      {init_exchange1, exchange_resp1} = handshake_pair(:ecdh_x25519_hkdf_sha256_aes_256_gcm)
      {init_exchange2, exchange_resp2} = handshake_pair(:ecdh_x25519_hkdf_sha256_aes_256_gcm)

      assert {:ok, key1} = SharedSecret.derive(init_exchange1, exchange_resp1)
      assert {:ok, key2} = SharedSecret.derive(init_exchange2, exchange_resp2)
      assert key1.k != key2.k
    end
  end

  describe "derive/2 with P-256" do
    test "produces a 32-byte AES-256-GCM key" do
      {init_exchange, exchange_resp} = handshake_pair(:ecdh_p256_hkdf_sha256_aes_256_gcm)

      assert {:ok, symmetric_key} = SharedSecret.derive(init_exchange, exchange_resp)
      assert symmetric_key.alg == :aes_256_gcm
      assert byte_size(symmetric_key.k) == 32
    end
  end

  describe "derive/2 error cases" do
    test "returns error when key types are mismatched (OKP vs ECC)" do
      {okp_init_exchange, _} = handshake_pair(:ecdh_x25519_hkdf_sha256_aes_256_gcm)
      ecc_key = ECC.generate(:es256)
      exchange_resp = %ExchangeResp{seq_num: 0, public_key: ecc_key}

      assert {:error, :unprocessable_entity, "unsupported or mismatched key"} =
               SharedSecret.derive(okp_init_exchange, exchange_resp)
    end

    test "returns error when exchange_resp has no private component" do
      {init_exchange, exchange_resp} = handshake_pair(:ecdh_x25519_hkdf_sha256_aes_256_gcm)
      peer_only_resp = Map.update!(exchange_resp, :public_key, &%{&1 | d: nil})

      assert {:error, :unprocessable_entity, "key derivation failed"} =
               SharedSecret.derive(init_exchange, peer_only_resp)
    end
  end
end
