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

defmodule Astarte.Pairing.FDO.Cbor.CoreTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.Cbor.Core

  describe "empty_payload/0" do
    test "returns a CBOR encoding of an empty list" do
      encoded = Core.empty_payload()
      assert CBOR.decode(encoded) == {:ok, [], ""}
    end
  end

  describe "build_rv_to2_addr_entry/4" do
    test "encodes a single rendezvous entry correctly" do
      ip = "192.168.1.10"
      dns = "example.com"
      port = 8080
      protocol = "https"

      encoded = Core.build_rv_to2_addr_entry(ip, dns, port, protocol)
      {:ok, decoded, ""} = CBOR.decode(encoded)

      assert is_list(decoded)
      [entry] = decoded
      assert entry == [ip, dns, port, protocol]
    end
  end

  describe "build_to1d_rv/1" do
    test "encodes a list of rendezvous entries" do
      entries = [
        ["1.1.1.1", "a.com", 1234, "http"],
        ["2.2.2.2", "b.com", 5678, "https"]
      ]

      encoded = Core.build_to1d_rv(entries)
      {:ok, decoded, ""} = CBOR.decode(encoded)

      assert decoded == [entries]
    end
  end

  describe "build_to0d/3" do
    test "encodes the owner voucher, wait time and nonce correctly" do
      ov = %{"owner" => "test_owner"}
      wait_seconds = 60
      nonce = "random_nonce"

      encoded = Core.build_to0d(ov, wait_seconds, nonce)
      {:ok, decoded, ""} = CBOR.decode(encoded)

      assert decoded == [ov, wait_seconds, nonce]
    end
  end

  describe "add_cbor_tag/1" do
    test "wraps payload in a CBOR tag struct" do
      payload = "abc123"
      tag = Core.add_cbor_tag(payload)

      assert %CBOR.Tag{tag: :bytes, value: ^payload} = tag
    end
  end

  describe "build_to1d_to0d_hash/1" do
    test "encodes a tuple of SHA256 tag and hash of the input" do
      data = "some_payload"
      encoded = Core.build_to1d_to0d_hash(data)
      {:ok, decoded, ""} = CBOR.decode(encoded)

      assert [47, hash] = decoded
      assert byte_size(hash) == 32

      expected_hash = :crypto.hash(:sha256, data)
      assert hash == expected_hash
    end
  end

  describe "build_to1d_blob_payload/2" do
    test "encodes a CBOR list containing two arguments" do
      rv = "rv_encoded"
      hash = "hash_encoded"

      encoded = Core.build_to1d_blob_payload(rv, hash)
      {:ok, decoded, ""} = CBOR.decode(encoded)

      assert decoded == [rv, hash]
    end
  end
end
