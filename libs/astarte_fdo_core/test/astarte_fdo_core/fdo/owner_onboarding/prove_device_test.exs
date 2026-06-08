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

defmodule Astarte.FDO.Core.OwnerOnboarding.ProveDeviceTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnerOnboarding.ProveDevice
  alias COSE.Keys.ECC

  describe "generate/0" do
    test "returns a ProveDevice struct" do
      result = ProveDevice.generate()
      assert %ProveDevice{} = result
    end

    test "generates 16-byte nonces" do
      %ProveDevice{
        nonce_to2_prove_dv: nonce_prove,
        nonce_to2_setup_dv: nonce_setup
      } = ProveDevice.generate()

      assert byte_size(nonce_prove) == 16
      assert byte_size(nonce_setup) == 16
    end

    test "generates a 16-byte guid" do
      %ProveDevice{guid: guid} = ProveDevice.generate()
      assert byte_size(guid) == 16
    end

    test "each call generates different nonces" do
      a = ProveDevice.generate()
      b = ProveDevice.generate()
      assert a.nonce_to2_prove_dv != b.nonce_to2_prove_dv
    end
  end

  describe "euph_nonce_claim_key/0" do
    test "returns -259" do
      assert ProveDevice.euph_nonce_claim_key() == -259
    end
  end

  describe "encode_sign/2 and decode/2 roundtrip" do
    setup do
      key = ECC.generate(:es256)
      device = ProveDevice.generate()
      %{key: key, device: device}
    end

    test "encode_sign returns a binary", %{key: key, device: device} do
      assert {:ok, binary} = ProveDevice.encode_sign(device, key)
      assert is_binary(binary)
    end

    test "decode recovers original fields", %{key: key, device: device} do
      {:ok, binary} = ProveDevice.encode_sign(device, key)

      assert {:ok, decoded} = ProveDevice.decode(binary, key)

      assert decoded.xb_key_exchange == device.xb_key_exchange
      assert decoded.nonce_to2_prove_dv == device.nonce_to2_prove_dv
      assert decoded.nonce_to2_setup_dv == device.nonce_to2_setup_dv
      assert decoded.guid == device.guid
    end

    test "decode with wrong key returns error", %{key: key, device: device} do
      {:ok, binary} = ProveDevice.encode_sign(device, key)
      wrong_key = ECC.generate(:es256)

      assert {:error, _} = ProveDevice.decode(binary, wrong_key)
    end
  end
end
