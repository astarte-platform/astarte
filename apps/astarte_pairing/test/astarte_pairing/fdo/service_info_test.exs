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
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  doctest Astarte.Pairing.FDO.ServiceInfo

  alias Astarte.Pairing.FDO.ServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session

  import Astarte.Helpers.FDO

  @owner_max_service_info 4096

  setup_all %{realm_name: realm_name} do
    device_id = sample_device_guid()
    hello_device = %{HelloDevice.generate() | device_id: device_id}
    ownership_voucher = sample_ownership_voucher()
    owner_key = sample_extracted_private_key()
    device_key = COSE.Keys.ECC.generate(:es256)
    {:ok, device_random, xb} = SessionKey.new(hello_device.kex_name, device_key)

    insert_voucher(realm_name, sample_private_key(), sample_cbor_voucher(), device_id)

    %{
      hello_device: hello_device,
      ownership_voucher: ownership_voucher,
      owner_key: owner_key,
      device_key: device_key,
      device_random: device_random,
      xb: xb
    }
  end

  setup context do
    %{
      astarte_instance_id: astarte_instance_id,
      hello_device: hello_device,
      ownership_voucher: ownership_voucher,
      realm: realm_name,
      owner_key: owner_key,
      xb: xb
    } = context

    {:ok, session} =
      Session.new(realm_name, hello_device, ownership_voucher, owner_key)

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      delete_session(realm_name, session.key)
    end)

    {:ok, session} = Session.build_session_secret(session, realm_name, owner_key, xb)
    {:ok, session} = Session.derive_key(session, realm_name)

    %{session: session}
  end

  describe "handle_msg_66/3" do
    test "successfully processes Msg 66, creates new voucher, and returns Msg 67", %{
      realm: realm_name,
      session: session
    } do
      new_hmac = :crypto.strong_rand_bytes(32)
      device_max_size = 2048

      assert {:ok, result_msg_67} =
               ServiceInfo.handle_msg_66(
                 realm_name,
                 session,
                 %DeviceServiceInfoReady{
                   replacement_hmac: new_hmac,
                   max_owner_service_info_sz: device_max_size
                 }
               )

      assert result_msg_67 == CBOR.encode([@owner_max_service_info]) |> COSE.tag_as_byte()
    end

    test "handles Credential Reuse (nil HMAC) correctly", %{
      realm: realm_name,
      session: session
    } do
      assert {:ok, _result} =
               ServiceInfo.handle_msg_66(
                 realm_name,
                 session,
                 %DeviceServiceInfoReady{
                   replacement_hmac: nil,
                   max_owner_service_info_sz: 2048
                 }
               )
    end

    test "handles the default recommended limit(nil info size) correctly", %{
      realm: realm_name,
      session: session
    } do
      new_hmac = :crypto.strong_rand_bytes(32)

      assert {:ok, _result} =
               ServiceInfo.handle_msg_66(
                 realm_name,
                 session,
                 %DeviceServiceInfoReady{
                   replacement_hmac: new_hmac,
                   max_owner_service_info_sz: nil
                 }
               )
    end

    test "handles the default recommended limit(0 info size) correctly", %{
      realm: realm_name,
      session: session
    } do
      new_hmac = :crypto.strong_rand_bytes(32)

      assert {:ok, _result} =
               ServiceInfo.handle_msg_66(
                 realm_name,
                 session,
                 %DeviceServiceInfoReady{
                   replacement_hmac: new_hmac,
                   max_owner_service_info_sz: 0
                 }
               )
    end

    test "returns error for wrong session", %{
      realm: realm_name
    } do
      new_hmac = :crypto.strong_rand_bytes(32)

      assert {:error, :failed_66} =
               ServiceInfo.handle_msg_66(
                 realm_name,
                 %Session{device_id: :crypto.strong_rand_bytes(16)},
                 %DeviceServiceInfoReady{
                   replacement_hmac: new_hmac,
                   max_owner_service_info_sz: 0
                 }
               )
    end
  end
end
