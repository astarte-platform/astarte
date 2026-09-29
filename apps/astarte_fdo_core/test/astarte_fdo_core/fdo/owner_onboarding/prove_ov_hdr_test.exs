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

defmodule Astarte.FDO.Core.OwnerOnboarding.ProveOVHdrTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.Hash
  alias Astarte.FDO.Core.OwnerOnboarding.ProveOVHdr
  alias COSE.Keys.ECC

  defp build_sample_proveovhdr do
    # Pre-encoded CBOR-compatible value for OV header (raw binary as CBOR-bstr source)
    cbor_ov_header = CBOR.encode("ov-header-placeholder")
    # Hash.encode returns a list [type_id, bstr] compatible to embed in a CBOR list
    cbor_hmac = Hash.encode(Hash.new(:sha256, "test-ov-header"))

    %ProveOVHdr{
      cbor_ov_header: cbor_ov_header,
      ov_header: nil,
      num_ov_entries: 2,
      hmac: nil,
      cbor_hmac: cbor_hmac,
      nonce_to2_prove_ov: :crypto.strong_rand_bytes(16),
      eb_sig_info: :es256,
      xa_key_exchange: :crypto.strong_rand_bytes(32),
      hello_device_hash: Hash.new(:sha256, "hello-device-msg"),
      max_owner_message_size: 65_536
    }
  end

  describe "encode/1" do
    test "returns a list with 8 elements" do
      result = ProveOVHdr.encode(build_sample_proveovhdr())
      assert length(result) == 8
    end

    test "second element is num_ov_entries" do
      p = build_sample_proveovhdr()
      result = ProveOVHdr.encode(p)
      assert Enum.at(result, 1) == p.num_ov_entries
    end

    test "last element is max_owner_message_size" do
      p = build_sample_proveovhdr()
      result = ProveOVHdr.encode(p)
      assert List.last(result) == p.max_owner_message_size
    end

    test "raises when both cbor_ov_header and ov_header are nil" do
      p = %{build_sample_proveovhdr() | cbor_ov_header: nil, ov_header: nil}
      assert_raise RuntimeError, fn -> ProveOVHdr.encode(p) end
    end

    test "raises when both cbor_hmac and hmac are nil" do
      p = %{build_sample_proveovhdr() | cbor_hmac: nil, hmac: nil}
      assert_raise RuntimeError, fn -> ProveOVHdr.encode(p) end
    end
  end

  describe "encode_cbor/1" do
    test "returns a binary" do
      result = ProveOVHdr.encode_cbor(build_sample_proveovhdr())
      assert is_binary(result)
    end

    test "decodes back to an 8-element list" do
      cbor = ProveOVHdr.encode_cbor(build_sample_proveovhdr())
      {:ok, list, ""} = CBOR.decode(cbor)
      assert length(list) == 8
    end
  end

  describe "encode_sign/4" do
    setup do
      owner_key = ECC.generate(:es256)
      # owner_pub_key is embedded as-is in the COSE unprotected header
      owner_pub_key = :crypto.strong_rand_bytes(32)
      dv_nonce = :crypto.strong_rand_bytes(16)
      p = build_sample_proveovhdr()

      %{owner_key: owner_key, owner_pub_key: owner_pub_key, dv_nonce: dv_nonce, p: p}
    end

    test "returns a binary", %{owner_key: k, owner_pub_key: pub, dv_nonce: nonce, p: p} do
      assert {:ok, result} = ProveOVHdr.encode_sign(p, nonce, pub, k)
      assert is_binary(result)
    end
  end
end
