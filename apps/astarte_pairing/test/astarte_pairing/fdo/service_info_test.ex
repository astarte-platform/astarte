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

defmodule Astarte.Pairing.FDO.ServiceInfoTest do
  use ExUnit.Case
  doctest Astarte.Pairing.FDO.ServiceInfo

  alias Astarte.Pairing.FDO.ServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias COSE.Messages.Encrypt0
  alias COSE.Keys

  @owner_max_service_info 4096
  @aes_256_gcm :aes_256_gcm

  setup do
    header_list = [
      # prot_ver
      101,
      # guid
      :crypto.strong_rand_bytes(16),
      # rendezvous info
      [[2, "ip.addr", 8080]],
      # device info
      "device_info_string",
      # pub_key
      :crypto.strong_rand_bytes(32),
      # cert_chain_hash
      :crypto.strong_rand_bytes(32)
    ]

    header_bstr = CBOR.encode(header_list)

    old_voucher = %OwnershipVoucher{
      protocol_version: 101,
      header: header_bstr,
      hmac: :crypto.strong_rand_bytes(32),
      cert_chain: nil,
      entries: []
    }

    {:ok, %{old_voucher: old_voucher}}
  end

  describe "handle_msg_66/4" do
    test "successfully processes Msg 66, creates new voucher, and returns Msg 67", %{
      old_voucher: old_voucher
    } do
      new_hmac = :crypto.strong_rand_bytes(32)
      device_max_size = 2048

      assert {:ok, result_msg_67} =
               ServiceInfo.handle_msg_66(
                 %DeviceServiceInfoReady{
                   replacement_hmac: new_hmac,
                   max_owner_service_info_sz: device_max_size
                 },
                 old_voucher
               )

      assert result_msg_67 == CBOR.encode([@owner_max_service_info]) |> COSE.tag_as_byte()
    end

    test "handles Credential Reuse (nil HMAC) correctly", %{
      old_voucher: old_voucher
    } do
      assert {:ok, _result} =
               ServiceInfo.handle_msg_66(
                 %DeviceServiceInfoReady{
                   replacement_hmac: nil,
                   max_owner_service_info_sz: 2048
                 },
                 old_voucher
               )
    end

    test "returns error if inner CBOR payload is malformed", %{
      old_voucher: old_voucher
    } do
      malformed_payload = "not_a_valid_payload"

      result = ServiceInfo.handle_msg_66(malformed_payload, old_voucher)

      assert {:error, :invalid_payload} = result
    end

    test "returns error if old voucher is invalid" do
      invalid_voucher = CBOR.encode("not a voucher")

      result =
        ServiceInfo.handle_msg_66(
          %DeviceServiceInfoReady{
            replacement_hmac: :crypto.strong_rand_bytes(32),
            max_owner_service_info_sz: 1024
          },
          invalid_voucher
        )

      assert {:error, :invalid_device_voucher} = result
    end
  end
end
