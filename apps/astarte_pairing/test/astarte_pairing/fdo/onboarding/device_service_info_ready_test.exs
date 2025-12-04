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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReadyTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.Pairing.FDO.Types.Hash

  @key %COSE.Keys.Symmetric{k: :crypto.strong_rand_bytes(16)}

  setup :verify_on_exit!

  describe "cbor_decode/1" do
    test "calls decode/1" do
      payload = [nil, nil]
      cbor_payload = CBOR.encode(payload)

      DeviceServiceInfoReady
      |> expect(:decode, fn ^payload ->
        response = %DeviceServiceInfoReady{max_owner_service_info_sz: nil, replacement_hmac: nil}
        {:ok, response}
      end)

      assert {:ok, _} = DeviceServiceInfoReady.cbor_decode(cbor_payload)
    end
  end

  describe "decode/1" do
    test "correctly decodes a full valid payload" do
      hmac = random_hmac()
      size = System.unique_integer([:positive])

      payload = [Hash.encode(hmac), size]

      assert {:ok, %DeviceServiceInfoReady{} = msg} = DeviceServiceInfoReady.decode(payload)
      assert msg.replacement_hmac == hmac
      assert msg.max_owner_service_info_sz == size
    end

    test "correctly decodes payload with nil ReplacementHMac (Credential Reuse)" do
      size = System.unique_integer([:positive])

      payload = [nil, size]

      assert {:ok, msg} = DeviceServiceInfoReady.decode(payload)
      assert msg.replacement_hmac == nil
      assert msg.max_owner_service_info_sz == size
    end

    test "correctly decodes payload with nil Size (Default Size)" do
      hmac = random_hmac()
      payload = [Hash.encode(hmac), nil]

      assert {:ok, msg} = DeviceServiceInfoReady.decode(payload)
      assert msg.replacement_hmac == hmac
      assert msg.max_owner_service_info_sz == nil
    end

    test "correctly decodes payload where both are nil" do
      payload = [nil, nil]

      assert {:ok, msg} = DeviceServiceInfoReady.decode(payload)
      assert msg.replacement_hmac == nil
      assert msg.max_owner_service_info_sz == nil
    end

    test "returns error if ReplacementHMac has invalid type" do
      payload = [12345, 1300]

      assert :error = DeviceServiceInfoReady.decode(payload)
    end

    test "returns error if maxOwnerServiceInfoSz has invalid type" do
      hmac = random_hmac()
      payload = [Hash.encode(hmac), "1300"]

      assert {:error, :invalid_size_type} = DeviceServiceInfoReady.decode(payload)
    end

    test "returns error if maxOwnerServiceInfoSz is negative" do
      hmac = random_hmac()

      payload = [Hash.encode(hmac), -100]

      assert {:error, :invalid_size_type} = DeviceServiceInfoReady.decode(payload)
    end

    test "returns error on invalid structure (wrong list length)" do
      payload = [nil]

      assert {:error, :message_body_error} = DeviceServiceInfoReady.decode(payload)
    end

    test "returns error on invalid structure (not a list)" do
      payload = %{"a" => 1}

      assert {:error, :message_body_error} = DeviceServiceInfoReady.decode(payload)
    end
  end

  def random_hmac do
    Hash.new(:hmac_sha256, @key, :crypto.strong_rand_bytes(16))
  end
end
