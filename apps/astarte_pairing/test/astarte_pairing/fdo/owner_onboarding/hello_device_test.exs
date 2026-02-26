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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.HelloDeviceTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.SignatureInfo

  describe "decode_hello_device/1" do
    setup do
      valid_data = %{
        max_size: 65_535,
        guid: %CBOR.Tag{tag: :bytes, value: <<1, 2, 3, 4>>},
        nonce: %CBOR.Tag{tag: :bytes, value: <<5, 6, 7, 8>>},
        kex_name: "DHKEXid14",
        cipher_name: :aes_256_gcm,
        easig_info: [-7, %CBOR.Tag{tag: :bytes, value: <<>>}]
      }

      hello_device_cbor = hello_device_list(valid_data) |> CBOR.encode()

      %{valid_data: valid_data, hello_device_cbor: hello_device_cbor}
    end

    test "successfully decodes a valid hello device structure", %{hello_device_cbor: cbor} do
      assert {:ok, %HelloDevice{}} = HelloDevice.decode(cbor)
    end

    test "successfully decodes a valid hello device CBOR payload", %{
      valid_data: data,
      hello_device_cbor: cbor
    } do
      assert {:ok, %HelloDevice{} = hello_device} = HelloDevice.decode(cbor)

      %CBOR.Tag{tag: :bytes, value: guid} = data.guid
      %CBOR.Tag{tag: :bytes, value: nonce} = data.nonce

      assert hello_device.max_size == data.max_size
      assert hello_device.guid == guid
      assert hello_device.nonce == nonce
      assert hello_device.kex_name == data.kex_name
      assert hello_device.cipher_name == data.cipher_name
      assert {:ok, hello_device.easig_info} == SignatureInfo.decode(data.easig_info)
    end

    test "returns error for invalid hello device format" do
      invalid_payload = [1, 2, 3]

      cbor_payload = CBOR.encode(invalid_payload)

      assert HelloDevice.decode(cbor_payload) == {:error, :message_body_error}
    end

    test "returns error when CBOR decode fails" do
      invalid_binary = "invalid_cbor"

      assert {:error, :message_body_error} == HelloDevice.decode(invalid_binary)
    end

    test "Decodes a hello device with ES384 signature info", %{valid_data: base_data} do
      es384_raw_sig_info = [-35, %CBOR.Tag{tag: :bytes, value: <<>>}]

      data_es384 = %{base_data | easig_info: es384_raw_sig_info}

      cbor_payload =
        hello_device_list(data_es384)
        |> CBOR.encode()

      assert {:ok, %HelloDevice{} = hello_device} = HelloDevice.decode(cbor_payload)
      assert hello_device.easig_info == :es384

      assert hello_device.kex_name == base_data.kex_name
    end
  end

  defp hello_device_list(data) do
    cipher = COSE.algorithm(data.cipher_name)
    [data.max_size, data.guid, data.nonce, data.kex_name, cipher, data.easig_info]
  end
end
