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
  use ExUnit.Case, async: true
  use Astarte.Cases.Data, async: true

  alias Astarte.Pairing.FDO.ServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session

  import Astarte.Helpers.FDO

  setup_all %{realm_name: realm_name} do
    device_id = sample_device_guid()
    hello_device = HelloDevice.generate(device_id: device_id)
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

  describe "build_owner_service_info/3 when device has more data" do
    test "stores partial device service info and returns empty owner service info", %{
      realm: realm_name,
      session: session
    } do
      service_info = %{{"devmode", "active"} => true}
      expected_service_info = %{{"devmode", "active"} => CBOR.encode(true)}

      device_info = %DeviceServiceInfo{
        is_more_service_info: true,
        service_info: service_info
      }

      empty_message = OwnerServiceInfo.empty()

      assert {:ok, empty_message} ==
               ServiceInfo.build_owner_service_info(
                 realm_name,
                 session,
                 device_info
               )

      {:ok, session_after} = Session.fetch(realm_name, session.key)

      assert expected_service_info == session_after.device_service_info
    end

    test "appends partial device service info and returns empty owner service info", %{
      realm: realm_name,
      session: session
    } do
      first_service_info = %{{"devmode", "active"} => true}
      second_service_info = %{{"devmode", "os"} => "linux"}

      expected_service_info = %{
        {"devmode", "active"} => CBOR.encode(true),
        {"devmode", "os"} => CBOR.encode("linux")
      }

      device_info = %DeviceServiceInfo{
        is_more_service_info: true,
        service_info: first_service_info
      }

      ServiceInfo.build_owner_service_info(realm_name, session, device_info)

      device_info = %DeviceServiceInfo{
        is_more_service_info: true,
        service_info: second_service_info
      }

      {:ok, session} = Session.fetch(realm_name, session.key)

      ServiceInfo.build_owner_service_info(realm_name, session, device_info)

      {:ok, session_after} = Session.fetch(realm_name, session.key)

      assert expected_service_info == session_after.device_service_info
    end
  end

  describe "build_owner_service_info/3 when device has sent all data" do
    test "registers device and returns owner service info", %{
      realm: realm_name,
      session: session
    } do
      service_info = %{{"devmod", "sn"} => "serial_number_1234"}

      device_info = %DeviceServiceInfo{
        is_more_service_info: false,
        service_info: service_info
      }

      assert {:ok, encoded_owner_service_info} =
               ServiceInfo.build_owner_service_info(
                 realm_name,
                 session,
                 device_info
               )

      assert is_binary(encoded_owner_service_info)
    end

    test "returns empty owner service info when all chunks are sent", %{
      realm: realm_name,
      session: session
    } do
      service_info = %{{"devmode", "active"} => true}

      device_info = %DeviceServiceInfo{
        is_more_service_info: false,
        service_info: service_info
      }

      ServiceInfo.build_owner_service_info(realm_name, session, device_info)

      {:ok, session_after} = Session.fetch(realm_name, session.key)

      empty_device_info = %DeviceServiceInfo{
        is_more_service_info: false,
        service_info: %{}
      }

      empty_owner_message = OwnerServiceInfo.empty()

      assert {:ok, empty_owner_message} ==
               ServiceInfo.build_owner_service_info(
                 realm_name,
                 session_after,
                 empty_device_info
               )
    end
  end
end
