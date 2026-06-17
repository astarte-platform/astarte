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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SecretHashTest do
  use ExUnit.Case, async: true

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SecretHash

  describe "new/2" do
    test "produces a struct with a 32-byte SHA256 hash" do
      secret = :crypto.strong_rand_bytes(32)
      msg = SecretHash.new(0, secret)

      assert msg.seq_num == 0
      assert byte_size(msg.key_hash) == 32
      assert msg.key_hash == :crypto.hash(:sha256, secret)
    end

    test "accepts any non-negative seq_num" do
      secret = :crypto.strong_rand_bytes(32)

      for seq <- [0, 1, 100, 65_535] do
        msg = SecretHash.new(seq, secret)
        assert msg.seq_num == seq
      end
    end

    test "different secrets produce different hashes" do
      s1 = :crypto.strong_rand_bytes(32)
      s2 = :crypto.strong_rand_bytes(32)

      assert SecretHash.new(0, s1).key_hash != SecretHash.new(0, s2).key_hash
    end
  end

  describe "cbor_encode/1 and cbor_decode/1 round-trip" do
    test "round-trips successfully" do
      secret = :crypto.strong_rand_bytes(32)
      original = SecretHash.new(42, secret)

      assert {:ok, decoded} = original |> SecretHash.cbor_encode() |> SecretHash.cbor_decode()
      assert decoded.seq_num == original.seq_num
      assert decoded.key_hash == original.key_hash
    end

    test "round-trips with seq_num 0" do
      msg = SecretHash.new(0, :crypto.strong_rand_bytes(32))
      assert {:ok, decoded} = msg |> SecretHash.cbor_encode() |> SecretHash.cbor_decode()
      assert decoded.seq_num == 0
    end
  end

  describe "cbor_decode/1 error cases" do
    test "returns error for non-CBOR binary" do
      assert {:error, :invalid_payload} = SecretHash.cbor_decode(<<0xFF, 0xFE>>)
    end

    test "returns error for wrong number of fields" do
      payload = CBOR.encode([42])
      assert {:error, :invalid_payload} = SecretHash.cbor_decode(payload)
    end

    test "returns error when seq_num is negative" do
      payload = CBOR.encode([-1, %CBOR.Tag{tag: :bytes, value: :crypto.hash(:sha256, "x")}])
      assert {:error, :invalid_payload} = SecretHash.cbor_decode(payload)
    end

    test "returns error when key_hash is not a CBOR bytes tag" do
      payload = CBOR.encode([0, "not_bytes"])
      assert {:error, :invalid_payload} = SecretHash.cbor_decode(payload)
    end

    test "returns error when key_hash has wrong length" do
      short_hash = :crypto.strong_rand_bytes(16)
      payload = CBOR.encode([0, %CBOR.Tag{tag: :bytes, value: short_hash}])
      assert {:error, :invalid_hash_length} = SecretHash.cbor_decode(payload)
    end
  end

  describe "encode/1" do
    test "returns a two-element list with the correct structure" do
      msg = SecretHash.new(7, :crypto.strong_rand_bytes(32))
      [seq_num, hash_tag] = SecretHash.encode(msg)

      assert seq_num == 7
      assert %CBOR.Tag{tag: :bytes, value: hash} = hash_tag
      assert hash == msg.key_hash
    end
  end
end
