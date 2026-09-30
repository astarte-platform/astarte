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

  alias Astarte.FDO.Core.OwnerOnboarding.EAToken
  alias Astarte.FDO.Core.OwnerOnboarding.ProveDevice
  alias COSE.Keys.ECC, as: Keys

  describe "euph_nonce_claim_key/0" do
    test "returns FDO unprotected header nonce claim key" do
      assert -259 == ProveDevice.euph_nonce_claim_key()
    end
  end

  describe "generate/0" do
    test "builds a valid ProveDevice payload scaffold" do
      generated = ProveDevice.generate()

      assert %ProveDevice{} = generated
      assert is_binary(generated.xb_key_exchange)
      assert byte_size(generated.nonce_to2_prove_dv) == 16
      assert byte_size(generated.nonce_to2_setup_dv) == 16
      assert byte_size(generated.guid) == 16
      assert generated.raw_eat_token == <<>>
    end
  end

  describe "encode_sign/2 and decode/2" do
    test "roundtrips a valid ProveDevice token" do
      key = Keys.generate(:es256)
      payload = ProveDevice.generate()

      assert {:ok, token} = ProveDevice.encode_sign(payload, key)
      assert {:ok, decoded} = ProveDevice.decode(token, key)

      assert decoded.xb_key_exchange == payload.xb_key_exchange
      assert decoded.nonce_to2_prove_dv == payload.nonce_to2_prove_dv
      assert decoded.nonce_to2_setup_dv == payload.nonce_to2_setup_dv
      assert decoded.guid == payload.guid
      assert decoded.raw_eat_token == token
    end

    test "returns error with wrong verification key" do
      key = Keys.generate(:es256)
      wrong_key = Keys.generate(:es256)

      payload = ProveDevice.generate()
      assert {:ok, token} = ProveDevice.encode_sign(payload, key)

      assert {:error, :invalid_message} = ProveDevice.decode(token, wrong_key)
    end
  end
end
