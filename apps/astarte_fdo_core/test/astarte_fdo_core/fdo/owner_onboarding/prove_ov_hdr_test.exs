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
  alias Astarte.FDO.Core.PublicKey
  alias COSE.Keys.ECC, as: Keys
  alias COSE.Messages.Sign1

  describe "encode/1" do
    test "encodes payload in expected order and format" do
      prove_ov_hdr = prove_ov_hdr_fixture()

      encoded = ProveOVHdr.encode(prove_ov_hdr)

      assert [
               %CBOR.Tag{tag: :bytes, value: <<1, 2, 3>>},
               2,
               hmac,
               %CBOR.Tag{tag: :bytes, value: nonce},
               [-7, %CBOR.Tag{tag: :bytes, value: <<>>}],
               %CBOR.Tag{tag: :bytes, value: <<4, 5, 6, 7>>},
               hello_hash,
               4096
             ] = encoded

      assert hmac == prove_ov_hdr.cbor_hmac
      assert nonce == prove_ov_hdr.nonce_to2_prove_ov
      assert hello_hash == Hash.encode(prove_ov_hdr.hello_device_hash)
    end
  end

  describe "encode_cbor/1" do
    test "returns CBOR binary for encoded payload" do
      prove_ov_hdr = prove_ov_hdr_fixture()

      encoded_cbor = ProveOVHdr.encode_cbor(prove_ov_hdr)

      assert is_binary(encoded_cbor)
      assert {:ok, decoded, ""} = CBOR.decode(encoded_cbor)
      assert decoded == ProveOVHdr.encode(prove_ov_hdr)
    end
  end

  describe "encode_sign/4" do
    test "signs CBOR payload with expected protected and unprotected headers" do
      prove_ov_hdr = prove_ov_hdr_fixture()
      owner_private_key = Keys.generate(:es256)

      owner_public_key =
        %PublicKey{
          type: :secp256r1,
          encoding: :cosekey,
          body: Keys.public_key(owner_private_key)
        }
        |> PublicKey.encode()

      dv_nonce = :crypto.strong_rand_bytes(16)

      assert {:ok, signed_cbor} =
               ProveOVHdr.encode_sign(prove_ov_hdr, dv_nonce, owner_public_key, owner_private_key)

      assert {:ok, sign1} = Sign1.decode_cbor(signed_cbor)
      assert :ok = Sign1.verify(sign1, owner_private_key)

      assert sign1.phdr[:alg] == :es256
      assert sign1.uhdr[256] == COSE.tag_as_byte(dv_nonce)
      assert sign1.uhdr[257] == owner_public_key

      assert %CBOR.Tag{tag: :bytes, value: payload_cbor} = sign1.payload
      assert {:ok, payload_decoded, ""} = CBOR.decode(payload_cbor)
      assert payload_decoded == ProveOVHdr.encode(prove_ov_hdr)
    end
  end

  defp prove_ov_hdr_fixture do
    %ProveOVHdr{
      cbor_ov_header: <<1, 2, 3>>,
      ov_header: nil,
      num_ov_entries: 2,
      cbor_hmac: Hash.new(:sha256, "ovhdr") |> Hash.encode(),
      hmac: nil,
      nonce_to2_prove_ov: :crypto.strong_rand_bytes(16),
      eb_sig_info: :es256,
      xa_key_exchange: <<4, 5, 6, 7>>,
      hello_device_hash: Hash.new(:sha256, "hello_device"),
      max_owner_message_size: 4096
    }
  end
end
