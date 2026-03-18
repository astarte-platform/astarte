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

defmodule Astarte.FDO.Core.OwnerOnboarding.EATokenTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnerOnboarding.EAToken
  alias COSE.Keys.ECC, as: Keys

  describe "build_ueid/1 and parse_ueid/1" do
    test "build_ueid prepends the FDO random prefix byte" do
      guid = :crypto.strong_rand_bytes(16)
      ueid = EAToken.build_ueid(guid)

      assert <<1, ^guid::binary-size(16)>> = ueid
    end

    test "parse_ueid returns the original guid" do
      guid = :crypto.strong_rand_bytes(16)
      ueid = EAToken.build_ueid(guid)

      assert {:ok, ^guid} = EAToken.parse_ueid(ueid)
    end

    test "parse_ueid returns error for ueid with wrong prefix" do
      bad_ueid = <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      assert {:error, :invalid_ueid} = EAToken.parse_ueid(bad_ueid)
    end

    test "parse_ueid returns error for guid of wrong size" do
      # prefix byte + only 8 bytes instead of 16
      bad_ueid = <<1, 0, 1, 2, 3, 4, 5, 6, 7>>
      assert {:error, :invalid_ueid} = EAToken.parse_ueid(bad_ueid)
    end
  end

  describe "encode_sign/3 and verify_decode_cbor/2 roundtrip" do
    setup do
      key = Keys.generate(:es256)
      guid = :crypto.strong_rand_bytes(16)
      nonce = :crypto.strong_rand_bytes(16)

      %{key: key, guid: guid, nonce: nonce}
    end

    test "signs and verifies successfully", %{key: key, guid: guid, nonce: nonce} do
      ueid = EAToken.build_ueid(guid)

      payload_claims = %{
        ueid: ueid |> COSE.tag_as_byte(),
        nonce: nonce |> COSE.tag_as_byte()
      }

      uhdr_claims = %{}

      cbor_token = EAToken.encode_sign(payload_claims, uhdr_claims, key)

      assert {:ok, decoded} = EAToken.verify_decode_cbor(cbor_token, key)
      # Payload values come back as CBOR byte tags after decode
      assert %CBOR.Tag{tag: :bytes, value: ^nonce} = decoded.payload.nonce
      assert %CBOR.Tag{tag: :bytes, value: ^ueid} = decoded.payload.ueid
    end

    test "returns error when verifying with wrong key", %{key: key, guid: guid, nonce: nonce} do
      ueid = EAToken.build_ueid(guid)

      payload_claims = %{
        ueid: ueid |> COSE.tag_as_byte(),
        nonce: nonce |> COSE.tag_as_byte()
      }

      cbor_token = EAToken.encode_sign(payload_claims, %{}, key)

      wrong_key = Keys.generate(:es256)

      assert {:error, _} = EAToken.verify_decode_cbor(cbor_token, wrong_key)
    end

    test "returns error for invalid binary" do
      key = Keys.generate(:es256)
      assert {:error, _} = EAToken.verify_decode_cbor(<<0xFF, 0x00>>, key)
    end
  end
end
