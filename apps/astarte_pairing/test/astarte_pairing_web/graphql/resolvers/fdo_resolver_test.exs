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

defmodule Astarte.PairingWeb.GraphQL.Resolvers.FdoResolverTest do
  use Astarte.Pairing.Cases.Data, async: true
  use Astarte.Pairing.Cases.OwnerKeys
  use Mimic

  import Astarte.Pairing.Helpers.FDO

  alias Astarte.Core.Device
  alias Astarte.DataAccess.Device, as: DeviceQueries
  alias Astarte.PairingWeb.GraphQL.Resolvers.FdoResolver
  alias Astarte.RPC.RealmManagement
  alias Astarte.Secrets
  alias Astarte.Secrets.Key

  @voucher_key_name "voucher_owner_key"

  describe "list_owner_keys/3" do
    test "lists the realm's keys for every algorithm", context do
      assert FdoResolver.list_owner_keys(nil, %{}, context.resolution) ==
               {:ok, context.expected_owner_keys}
    end

    test "lists every algorithm when the key algorithm is null", context do
      assert FdoResolver.list_owner_keys(nil, %{key_algorithm: nil}, context.resolution) ==
               {:ok, context.expected_owner_keys}
    end

    test "lists only the keys of the requested algorithm", context do
      assert FdoResolver.list_owner_keys(nil, %{key_algorithm: "ecdsa-p256"}, context.resolution) ==
               {:ok, Map.take(context.expected_owner_keys, [:es256])}
    end
  end

  describe "get_owner_key/3" do
    test "returns the key's public PEM", context do
      {:ok, %Key{public_pem: public_pem}} =
        Secrets.get_key("owner_key_a", namespace: context.namespace)

      args = %{key_algorithm: "ecdsa-p256", key_name: "owner_key_a"}

      assert FdoResolver.get_owner_key(nil, args, context.resolution) ==
               {:ok, %{key_name: "owner_key_a", public_key: public_pem}}
    end

    test "returns an error when the algorithm is invalid", context do
      args = %{key_algorithm: "bogus", key_name: "owner_key_a"}

      assert FdoResolver.get_owner_key(nil, args, context.resolution) ==
               {:error, :invalid_key_algorithm}
    end

    test "returns an error when the key doesn't exist", context do
      args = %{key_algorithm: "ecdsa-p256", key_name: "missing"}

      assert FdoResolver.get_owner_key(nil, args, context.resolution) ==
               {:error, :key_not_found}
    end
  end

  describe "create_or_upload_owner_key/3" do
    # keys are shared by the module, delete only the one created here
    setup %{namespace: namespace} do
      key_name = "new_key_#{System.unique_integer([:positive])}"

      on_exit(fn ->
        with {:ok, _key} <- Secrets.get_key(key_name, namespace: namespace) do
          delete_owner_key(key_name, namespace)
        end
      end)

      %{key_name: key_name}
    end

    test "creates the key and returns its public PEM", context do
      args = %{action: "create", key_name: context.key_name, key_algorithm: "ecdsa-p256"}

      assert {:ok, public_pem} =
               FdoResolver.create_or_upload_owner_key(nil, args, context.resolution)

      assert {:ok, %Key{public_pem: ^public_pem}} =
               Secrets.get_key(context.key_name, namespace: context.namespace)
    end

    test "returns the validation error and creates nothing when options are invalid", context do
      args = %{action: "create", key_name: context.key_name}

      assert {:error, %Ecto.Changeset{}} =
               FdoResolver.create_or_upload_owner_key(nil, args, context.resolution)

      refute match?({:ok, _}, Secrets.get_key(context.key_name, namespace: context.namespace))
    end
  end

  describe "list_ownership_vouchers/3" do
    test "returns no vouchers for a realm without any", context do
      assert FdoResolver.list_ownership_vouchers(nil, %{}, context.resolution) == {:ok, []}
    end
  end

  describe "register_ownership_voucher/3" do
    setup :setup_registrable_voucher

    test "registers the voucher and returns the owner's public key and the GUID", context do
      %{args: args, owner_public_pem: owner_public_pem, resolution: resolution} = context

      assert FdoResolver.register_ownership_voucher(nil, args, resolution) ==
               {:ok, %{public_key: owner_public_pem, guid: registrable_voucher_guid()}}

      assert {:ok, [%{guid: guid}]} = FdoResolver.list_ownership_vouchers(nil, %{}, resolution)
      assert guid == registrable_voucher_guid()
    end

    test "registers the voucher's device with its initial introspection", context do
      %{args: args, device_id: device_id, realm: realm, resolution: resolution} = context

      introspection = [
        %{interface: "org.astarteplatform.Values", major_version: 0, minor_version: 4},
        %{interface: "org.astarteplatform.OtherValues", major_version: 1, minor_version: 0}
      ]

      args = Map.put(args, :initial_introspection, introspection)
      {:ok, _response} = FdoResolver.register_ownership_voucher(nil, args, resolution)

      assert {:ok, device} = DeviceQueries.fetch(realm, device_id)

      assert device.introspection == %{
               "org.astarteplatform.Values" => 0,
               "org.astarteplatform.OtherValues" => 1
             }

      assert device.introspection_minor == %{
               "org.astarteplatform.Values" => 4,
               "org.astarteplatform.OtherValues" => 0
             }
    end

    test "returns the validation error when the owner key doesn't exist", context do
      args = %{context.args | key_name: "missing"}

      assert {:error, %Ecto.Changeset{}} =
               FdoResolver.register_ownership_voucher(nil, args, context.resolution)
    end
  end

  describe "delete_ownership_voucher/3" do
    setup :setup_registrable_voucher

    test "deletes the voucher and returns its GUID", context do
      %{args: args, realm: realm, resolution: resolution} = context
      guid = registrable_voucher_guid()
      {:ok, _response} = FdoResolver.register_ownership_voucher(nil, args, resolution)

      # realm management deletes the device, it doesn't run here
      hw_id = args.hw_id
      expect(RealmManagement, :delete_device, fn ^realm, ^hw_id -> :ok end)

      assert FdoResolver.delete_ownership_voucher(nil, %{guid: guid}, resolution) == {:ok, guid}
      assert FdoResolver.list_ownership_vouchers(nil, %{}, resolution) == {:ok, []}
    end

    test "reports a GUID that isn't a UUID as not found", context do
      assert FdoResolver.delete_ownership_voucher(nil, %{guid: "not-a-guid"}, context.resolution) ==
               {:error, :not_found}
    end

    test "reports an unknown GUID as not found", context do
      assert FdoResolver.delete_ownership_voucher(nil, %{guid: UUID.uuid4()}, context.resolution) ==
               {:error, :not_found}
    end
  end

  defp setup_registrable_voucher(context) do
    %{realm: realm, astarte_instance_id: astarte_instance_id, namespace: namespace} = context

    {:ok, owner_key} = COSE.Keys.from_pem(registrable_voucher_owner_key_pem())
    :ok = Secrets.import_key(@voucher_key_name, :es256, owner_key, namespace: namespace)

    {:ok, %Key{public_pem: owner_public_pem}} =
      Secrets.get_key(@voucher_key_name, namespace: namespace)

    on_exit(fn -> delete_owner_key(@voucher_key_name, namespace) end)

    device_id = Device.random_device_id()
    cleanup_registrable_voucher_on_exit(astarte_instance_id, realm, device_id)

    args = %{
      hw_id: Device.encode_device_id(device_id),
      ownership_voucher: registrable_voucher_pem(),
      key_name: @voucher_key_name,
      key_algorithm: "ecdsa-p256"
    }

    %{args: args, device_id: device_id, owner_public_pem: owner_public_pem}
  end
end
