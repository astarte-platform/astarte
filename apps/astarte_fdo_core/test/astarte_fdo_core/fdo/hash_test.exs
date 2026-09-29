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

defmodule Astarte.FDO.Core.HashTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.Hash
  alias COSE.Keys.Symmetric

  describe "new/2 (hash)" do
    test "creates a sha256 hash" do
      value = "hello world"
      hash = Hash.new(:sha256, value)

      assert %Hash{type: :sha256} = hash
      assert hash.hash == :crypto.hash(:sha256, value)
    end

    test "creates a sha384 hash" do
      value = "hello world"
      hash = Hash.new(:sha384, value)

      assert %Hash{type: :sha384} = hash
      assert hash.hash == :crypto.hash(:sha384, value)
    end
  end

  describe "new/3 (hmac)" do
    setup do
      key = %Symmetric{k: :crypto.strong_rand_bytes(32)}
      %{key: key}
    end

    test "creates an hmac_sha256 hash", %{key: key} do
      value = "test data"
      hash = Hash.new(:hmac_sha256, key, value)

      assert %Hash{type: :hmac_sha256} = hash
      assert hash.hash == :crypto.mac(:hmac, :sha256, key.k, value)
    end

    test "creates an hmac_sha384 hash", %{key: key} do
      value = "test data"
      hash = Hash.new(:hmac_sha384, key, value)

      assert %Hash{type: :hmac_sha384} = hash
      assert hash.hash == :crypto.mac(:hmac, :sha384, key.k, value)
    end
  end

  describe "encode/1 and decode/1 (roundtrip)" do
    test "encodes and decodes sha256 hash" do
      original = Hash.new(:sha256, "roundtrip test")
      encoded = Hash.encode(original)

      assert {:ok, decoded} = Hash.decode(encoded)
      assert decoded == original
    end

    test "encodes and decodes sha384 hash" do
      original = Hash.new(:sha384, "roundtrip test")
      encoded = Hash.encode(original)

      assert {:ok, decoded} = Hash.decode(encoded)
      assert decoded == original
    end
  end

  describe "encode_cbor/1 and decode_cbor/1 (roundtrip)" do
    test "encodes to binary CBOR and decodes back" do
      original = Hash.new(:sha256, "cbor roundtrip")
      cbor_binary = Hash.encode_cbor(original)

      assert is_binary(cbor_binary)
      assert {:ok, decoded} = Hash.decode_cbor(cbor_binary)
      assert decoded == original
    end

    test "returns :error for invalid CBOR binary" do
      assert :error = Hash.decode_cbor(<<0xFF, 0xFF, 0xFF>>)
    end

    test "returns :error for CBOR with unknown hash type" do
      # Encode a list with an unknown type integer
      bad_cbor = CBOR.encode([99, %CBOR.Tag{tag: :bytes, value: <<1, 2, 3>>}])
      assert :error = Hash.decode_cbor(bad_cbor)
    end
  end

  describe "decode/1 edge cases" do
    test "returns :error for non-list input" do
      assert :error = Hash.decode("not a list")
    end

    test "returns :error for list with wrong structure" do
      assert :error = Hash.decode([1, 2, 3])
    end

    test "returns :error for list with non-bytes-tagged hash" do
      # type -16 is sha256, but value is not a byte tag
      assert :error = Hash.decode([-16, "not_a_byte_tag"])
    end
  end
end
