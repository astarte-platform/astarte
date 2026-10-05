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

defmodule Astarte.FDO.Core.OwnerOnboarding.SetupDevicePayloadTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnerOnboarding.SetupDevicePayload
  alias Astarte.FDO.Core.OwnershipVoucher.RendezvousInfo
  alias Astarte.FDO.Core.PublicKey
  alias COSE.Keys.ECC, as: Keys
  alias COSE.Messages.Sign1

  @rendezvous_info_cbor [
    [
      [5, %CBOR.Tag{tag: :bytes, value: "ufdo.astarte.localhost"}],
      [12, %CBOR.Tag{tag: :bytes, value: <<1>>}],
      [3, %CBOR.Tag{tag: :bytes, value: <<24, 80>>}],
      [4, %CBOR.Tag{tag: :bytes, value: <<25, 31, 105>>}],
      [13, %CBOR.Tag{tag: :bytes, value: "\n"}]
    ]
  ]

  describe "to_cbor_list/1" do
    test "returns SetupDevice payload fields in FDO order" do
      payload = setup_device_fixture()

      assert [rv_info, guid, nonce, owner2_key] = SetupDevicePayload.to_cbor_list(payload)

      assert rv_info == RendezvousInfo.encode(payload.rendezvous_info)
      assert guid == COSE.tag_as_byte(payload.guid)
      assert nonce == COSE.tag_as_byte(payload.nonce_setup_device)
      assert owner2_key == PublicKey.encode(payload.owner2_key)
    end
  end

  describe "encode/1" do
    test "encodes SetupDevice payload to CBOR binary" do
      payload = setup_device_fixture()

      encoded = SetupDevicePayload.encode(payload)

      assert is_binary(encoded)
      assert {:ok, decoded, ""} = CBOR.decode(encoded)
      assert decoded == SetupDevicePayload.to_cbor_list(payload)
    end
  end

  describe "encode_sign/2" do
    test "signs encoded payload as COSE_Sign1" do
      payload = setup_device_fixture()
      owner_private_key = Keys.generate(:es256)

      assert {:ok, sign1_tag} = SetupDevicePayload.encode_sign(payload, owner_private_key)
      assert {:ok, sign1} = Sign1.decode(sign1_tag)
      assert :ok = Sign1.verify(sign1, owner_private_key)

      assert sign1.phdr[:alg] == :es256

      assert %CBOR.Tag{tag: :bytes, value: payload_cbor} = sign1.payload
      assert payload_cbor == SetupDevicePayload.encode(payload)
    end

    test "returns error when verifying with wrong key" do
      payload = setup_device_fixture()
      owner_private_key = Keys.generate(:es256)
      wrong_key = Keys.generate(:es256)

      assert {:ok, sign1_tag} = SetupDevicePayload.encode_sign(payload, owner_private_key)
      assert {:ok, sign1} = Sign1.decode(sign1_tag)

      assert {:error, :invalid_signature} = Sign1.verify(sign1, wrong_key)
    end
  end

  defp setup_device_fixture do
    {:ok, rendezvous_info} = RendezvousInfo.decode(@rendezvous_info_cbor)

    owner2_key = %PublicKey{
      type: :secp256r1,
      encoding: :cosekey,
      body: :crypto.strong_rand_bytes(65)
    }

    %SetupDevicePayload{
      rendezvous_info: rendezvous_info,
      guid: :crypto.strong_rand_bytes(16),
      nonce_setup_device: :crypto.strong_rand_bytes(16),
      owner2_key: owner2_key
    }
  end
end
