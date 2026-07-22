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

defmodule Astarte.FDO.Core.Rendezvous.OwnerSignTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.Hash
  alias Astarte.FDO.Core.Rendezvous.OwnerSign
  alias Astarte.FDO.Core.Rendezvous.OwnerSign.TO0D
  alias Astarte.FDO.Core.Rendezvous.OwnerSign.TO1D
  alias Astarte.FDO.Core.Rendezvous.RvTO2Addr
  alias COSE.Keys.ECC, as: COSEKeysECC
  alias COSE.Messages.Sign1

  describe "encode_sign_with_hash/2" do
    test "encodes TO0D, injects its hash in TO1D, and signs TO1D payload" do
      owner_sign = owner_sign_fixture()
      owner_key = COSEKeysECC.generate(:es256)

      assert {:ok, [%CBOR.Tag{tag: :bytes, value: to0d_cbor}, sign1_tag]} =
               OwnerSign.encode_sign_with_hash(owner_sign, owner_key)

      assert to0d_cbor == TO0D.encode_cbor(owner_sign.to0d)

      assert {:ok, sign1} = Sign1.decode(sign1_tag)
      assert :ok = Sign1.verify(sign1, owner_key)

      assert %CBOR.Tag{tag: :bytes, value: to1d_payload_cbor} = sign1.payload
      assert {:ok, [rv_to2_addr, to0d_hash], ""} = CBOR.decode(to1d_payload_cbor)

      assert rv_to2_addr == RvTO2Addr.encode_list(owner_sign.to1d.rv_to2_addr)
      assert to0d_hash == Hash.new(:sha256, to0d_cbor) |> Hash.encode()
    end

    test "produces a signature that fails verification with a different key" do
      owner_sign = owner_sign_fixture()
      owner_key = COSEKeysECC.generate(:es256)
      wrong_key = COSEKeysECC.generate(:es256)

      assert {:ok, [_, sign1_tag]} = OwnerSign.encode_sign_with_hash(owner_sign, owner_key)
      assert {:ok, sign1} = Sign1.decode(sign1_tag)

      assert {:error, :invalid_signature} = Sign1.verify(sign1, wrong_key)
    end
  end

  describe "encode_sign_cbor_with_hash/2" do
    test "returns CBOR encoded OwnerSign payload" do
      owner_sign = owner_sign_fixture()
      owner_key = COSEKeysECC.generate(:es256)

      assert {:ok, owner_sign_cbor} = OwnerSign.encode_sign_cbor_with_hash(owner_sign, owner_key)
      assert {:ok, [%CBOR.Tag{tag: :bytes}, sign1_tag], ""} = CBOR.decode(owner_sign_cbor)
      assert {:ok, _sign1} = Sign1.decode(sign1_tag)
    end
  end

  defp owner_sign_fixture do
    to0d = %TO0D{
      cbor_decoded_ownership_voucher: [1, "ov", %{"k" => 7}],
      wait_seconds: 600,
      nonce_to0_sign: :crypto.strong_rand_bytes(16)
    }

    to1d = %TO1D{
      rv_to2_addr: [
        %RvTO2Addr{dns: "rv.example.com", port: 443, protocol: :https}
      ],
      to0d_hash: Hash.new(:sha256, "placeholder")
    }

    %OwnerSign{to0d: to0d, to1d: to1d}
  end
end
