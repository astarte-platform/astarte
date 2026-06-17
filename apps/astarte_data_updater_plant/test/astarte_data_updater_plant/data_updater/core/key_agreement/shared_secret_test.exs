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

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SharedSecret
  alias COSE.Keys.ECC
  alias COSE.Keys.OKP

  describe "derive/3 with X25519" do
    test "produces a 32-byte key" do
      alice = OKP.generate(:enc)
      bob = OKP.generate(:enc)
      salt = :crypto.strong_rand_bytes(32)

      assert {:ok, key} = SharedSecret.derive(alice, bob, salt)
      assert byte_size(key) == 32
    end

    test "both sides derive the same key" do
      alice = OKP.generate(:enc)
      bob = OKP.generate(:enc)
      salt = :crypto.strong_rand_bytes(32)

      assert {:ok, key_ab} = SharedSecret.derive(alice, bob, salt)
      assert {:ok, key_ba} = SharedSecret.derive(bob, alice, salt)
      assert key_ab == key_ba
    end

    test "different salts produce different keys" do
      alice = OKP.generate(:enc)
      bob = OKP.generate(:enc)
      salt1 = :crypto.strong_rand_bytes(32)
      salt2 = :crypto.strong_rand_bytes(32)

      assert {:ok, key1} = SharedSecret.derive(alice, bob, salt1)
      assert {:ok, key2} = SharedSecret.derive(alice, bob, salt2)
      assert key1 != key2
    end

    test "different key pairs produce different keys" do
      alice = OKP.generate(:enc)
      bob = OKP.generate(:enc)
      carol = OKP.generate(:enc)
      salt = :crypto.strong_rand_bytes(32)

      assert {:ok, key_ab} = SharedSecret.derive(alice, bob, salt)
      assert {:ok, key_ac} = SharedSecret.derive(alice, carol, salt)
      assert key_ab != key_ac
    end
  end

  describe "derive/3 with P-256" do
    test "produces a 32-byte key" do
      alice = ECC.generate(:es256)
      bob = ECC.generate(:es256)
      salt = :crypto.strong_rand_bytes(32)

      assert {:ok, key} = SharedSecret.derive(alice, bob, salt)
      assert byte_size(key) == 32
    end

    test "both sides derive the same key" do
      alice = ECC.generate(:es256)
      bob = ECC.generate(:es256)
      salt = :crypto.strong_rand_bytes(32)

      assert {:ok, key_ab} = SharedSecret.derive(alice, bob, salt)
      assert {:ok, key_ba} = SharedSecret.derive(bob, alice, salt)
      assert key_ab == key_ba
    end

    test "different salts produce different keys" do
      alice = ECC.generate(:es256)
      bob = ECC.generate(:es256)
      salt1 = :crypto.strong_rand_bytes(32)
      salt2 = :crypto.strong_rand_bytes(32)

      assert {:ok, key1} = SharedSecret.derive(alice, bob, salt1)
      assert {:ok, key2} = SharedSecret.derive(alice, bob, salt2)
      assert key1 != key2
    end
  end

  describe "derive/3 error cases" do
    test "returns error when key types are mismatched (OKP vs ECC)" do
      okp_key = OKP.generate(:enc)
      ecc_key = ECC.generate(:es256)
      salt = :crypto.strong_rand_bytes(32)

      assert {:error, :key_mismatch_or_unsupported} =
               SharedSecret.derive(okp_key, ecc_key, salt)
    end

    test "returns error when my_key has no private component" do
      full = OKP.generate(:enc)
      pub_only = %OKP{full | d: nil}
      peer = OKP.generate(:enc)
      salt = :crypto.strong_rand_bytes(32)

      assert {:error, _} = SharedSecret.derive(pub_only, peer, salt)
    end
  end
end
