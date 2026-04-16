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
  alias COSE.Keys.ECC

  @rendezvous_info_cbor [
    [
      [5, %CBOR.Tag{tag: :bytes, value: "ufdo.astarte.localhost"}],
      [12, %CBOR.Tag{tag: :bytes, value: <<1>>}],
      [3, %CBOR.Tag{tag: :bytes, value: <<24, 80>>}],
      [4, %CBOR.Tag{tag: :bytes, value: <<25, 31, 105>>}],
      [13, %CBOR.Tag{tag: :bytes, value: "\n"}]
    ]
  ]

  defp build_payload do
    {:ok, rv_info} = RendezvousInfo.decode(@rendezvous_info_cbor)

    owner2_key = %PublicKey{
      type: :secp256r1,
      encoding: :x509,
      body: :crypto.strong_rand_bytes(32)
    }

    %SetupDevicePayload{
      rendezvous_info: rv_info,
      guid: :crypto.strong_rand_bytes(16),
      nonce_setup_device: :crypto.strong_rand_bytes(16),
      owner2_key: owner2_key
    }
  end

  describe "to_cbor_list/1" do
    test "returns a 4-element list" do
      result = SetupDevicePayload.to_cbor_list(build_payload())
      assert length(result) == 4
    end

    test "guid is wrapped as a bstr tag" do
      p = build_payload()
      [_, guid_tagged, _, _] = SetupDevicePayload.to_cbor_list(p)
      assert %CBOR.Tag{tag: :bytes, value: p_guid} = guid_tagged
      assert p_guid == p.guid
    end

    test "nonce is wrapped as a bstr tag" do
      p = build_payload()
      [_, _, nonce_tagged, _] = SetupDevicePayload.to_cbor_list(p)
      assert %CBOR.Tag{tag: :bytes} = nonce_tagged
    end
  end

  describe "encode/1" do
    test "returns a binary" do
      result = SetupDevicePayload.encode(build_payload())
      assert is_binary(result)
    end

    test "decodes back to a 4-element list" do
      cbor = SetupDevicePayload.encode(build_payload())
      {:ok, list, ""} = CBOR.decode(cbor)
      assert length(list) == 4
    end
  end

  describe "encode_sign/2" do
    test "returns {:ok, cbor_tag} when given a valid owner key" do
      key = ECC.generate(:es256)
      p = build_payload()

      assert {:ok, signed} = SetupDevicePayload.encode_sign(p, key)
      assert %CBOR.Tag{} = signed
    end
  end
end
