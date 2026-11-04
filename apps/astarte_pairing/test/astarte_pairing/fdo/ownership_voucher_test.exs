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

defmodule Astarte.Pairing.FDO.OwnershipVoucherTest do
  use Astarte.Pairing.Cases.Data, async: true
  use Mimic

  import Astarte.Pairing.Helpers.FDO
  import ExUnit.CaptureLog

  alias Astarte.Core.Device
  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.Pairing.FDO
  alias Astarte.Secrets

  @key_name "owner_key"

  setup_all %{realm_name: realm_name} do
    {:ok, namespace} = Secrets.create_fdo_namespace(realm_name, :es256)
    {:ok, owner_key} = COSE.Keys.from_pem(registrable_voucher_owner_key_pem())
    :ok = Secrets.import_key(@key_name, :es256, owner_key, namespace: namespace)
    on_exit(fn -> delete_owner_keys(namespace) end)

    :ok
  end

  setup %{realm_name: realm_name, astarte_instance_id: astarte_instance_id} do
    device_id = Device.random_device_id()

    cleanup_registrable_voucher_on_exit(astarte_instance_id, realm_name, device_id)

    params = %{
      "hw_id" => Device.encode_device_id(device_id),
      "ownership_voucher" => registrable_voucher_pem(),
      "key_name" => @key_name,
      "key_algorithm" => "es256"
    }

    %{guid: registrable_voucher_guid(), params: params}
  end

  describe "register/2" do
    test "logs the claimed voucher when it can't be stored", context do
      %{realm_name: realm, guid: guid, params: params} = context
      expect(LoadRequest, :store_voucher, fn _req, _expiry -> {:error, :connection_error} end)

      log =
        capture_log([metadata: [:realm, :fdo_guid, :reason]], fn ->
          assert FDO.OwnershipVoucher.register(params, realm) == {:error, :connection_error}
        end)

      assert log =~
               "Ownership was already claimed on the rendezvous server but the voucher could not be persisted!"

      assert log =~ "realm=#{realm}"
      assert log =~ "fdo_guid=#{guid}"
      assert log =~ "reason=connection_error"
    end

    test "logs the claimed voucher when its device can't be registered", context do
      %{realm_name: realm, astarte_instance_id: astarte_instance_id} = context
      %{guid: guid, params: params} = context

      set_device_registration_limit(realm, 0)

      on_exit(fn ->
        setup_database_access(astarte_instance_id)
        set_device_registration_limit(realm, nil)
      end)

      log =
        capture_log([metadata: [:realm, :fdo_guid, :reason]], fn ->
          assert FDO.OwnershipVoucher.register(params, realm) ==
                   {:error, :device_registration_limit_reached}
        end)

      assert log =~
               "Ownership was already claimed on the rendezvous server but the device could not be registered!"

      assert log =~ "realm=#{realm}"
      assert log =~ "fdo_guid=#{guid}"
      assert log =~ "reason=device_registration_limit_reached"
    end
  end

  describe "compatible_owner_keys/2" do
    test "lists the owner keys of the voucher's key algorithm", %{realm_name: realm} do
      assert FDO.OwnershipVoucher.compatible_owner_keys(realm, registrable_voucher_pem()) ==
               {:ok, %{es256: [@key_name]}}
    end

    test "returns an error for a malformed voucher", %{realm_name: realm} do
      assert {:error, _reason} =
               FDO.OwnershipVoucher.compatible_owner_keys(realm, "not a voucher")
    end
  end
end
