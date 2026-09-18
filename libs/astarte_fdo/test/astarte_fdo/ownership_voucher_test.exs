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

defmodule Astarte.FDO.OwnershipVoucherTest do
  use Astarte.Cases.Data, async: true
  use Mimic

  alias Astarte.Core.Device
  alias Astarte.DataAccess.FDO.OwnershipVoucher, as: OwnershipVoucherStruct
  alias Astarte.DataAccess.FDO.Queries
  alias Astarte.FDO.Core.Hash
  alias Astarte.FDO.Core.OwnershipVoucher, as: OwnershipVoucherCore
  alias Astarte.FDO.Core.OwnershipVoucher.Header
  alias Astarte.FDO.Core.PublicKey
  alias Astarte.FDO.Helpers
  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.FDO.TO0
  alias Astarte.RPC.RealmManagement
  alias Astarte.Secrets
  alias COSE.Messages.Sign1

  setup context do
    %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} = context

    RealmManagement
    |> stub(:delete_device, fn _, _ -> :ok end)

    guid = :crypto.strong_rand_bytes(16)
    device_id = Device.random_device_id()
    encoded_device_id = Device.encode_device_id(device_id)

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      Queries.delete_ownership_voucher(guid)
    end)

    %{
      guid: guid,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    }
  end

  describe "delete/2" do
    test "revokes the rendezvous registration and removes the voucher", ctx do
      %{
        realm_name: realm_name,
        guid: guid,
        device_id: device_id,
        encoded_device_id: encoded_device_id
      } = ctx

      ownership_voucher = %OwnershipVoucherStruct{
        guid: guid,
        realm: realm_name,
        device_id: device_id,
        key_name: "some_key",
        key_algorithm: :es256,
        voucher_data: Helpers.sample_cbor_voucher()
      }

      :ok = Queries.create_ownership_voucher(ownership_voucher)

      Secrets
      |> expect(:get_key_for_guid, fn ^realm_name, ^guid -> {:ok, :fake_owner_key} end)

      TO0
      |> expect(:revoke_ownership_voucher, fn ^realm_name, _decoded_voucher, :fake_owner_key ->
        :ok
      end)

      RealmManagement
      |> expect(:delete_device, fn ^realm_name, ^encoded_device_id -> :ok end)

      assert {:ok, _} = OwnershipVoucher.delete(realm_name, guid)
      assert {:error, :not_found} = Queries.fetch_ownership_voucher(guid)
    end

    test "deletes the voucher even if the device does not exist", context do
      %{
        realm_name: realm_name,
        guid: guid,
        device_id: device_id,
        encoded_device_id: encoded_device_id
      } = context

      ownership_voucher = %OwnershipVoucherStruct{
        guid: guid,
        device_id: device_id,
        realm: realm_name,
        key_name: "some_key",
        key_algorithm: :es256,
        voucher_data: Helpers.sample_cbor_voucher()
      }

      :ok = Queries.create_ownership_voucher(ownership_voucher)

      Secrets
      |> expect(:get_key_for_guid, fn ^realm_name, ^guid -> {:ok, :fake_owner_key} end)

      TO0
      |> expect(:revoke_ownership_voucher, fn ^realm_name, _decoded_voucher, :fake_owner_key ->
        :ok
      end)

      RealmManagement
      |> expect(:delete_device, fn ^realm_name, ^encoded_device_id ->
        {:error, :device_not_found}
      end)

      assert {:ok, _} = OwnershipVoucher.delete(realm_name, guid)
      assert {:error, :not_found} = Queries.fetch_ownership_voucher(guid)
    end

    test "does not delete the voucher if the rendezvous revocation fails", ctx do
      %{realm_name: realm_name, guid: guid, device_id: device_id} = ctx

      ownership_voucher = %OwnershipVoucherStruct{
        guid: guid,
        device_id: device_id,
        key_name: "some_key",
        key_algorithm: :es256,
        realm: realm_name,
        voucher_data: Helpers.sample_cbor_voucher()
      }

      :ok = Queries.create_ownership_voucher(ownership_voucher)

      Secrets
      |> expect(:get_key_for_guid, fn ^realm_name, ^guid -> :error end)

      assert {:error, :rendezvous_revocation_failed} =
               OwnershipVoucher.delete(realm_name, guid)

      assert {:ok, _voucher} = Queries.fetch_ownership_voucher(guid)
    end

    test "returns {:error, :not_found} for an unknown guid", ctx do
      %{realm_name: realm_name} = ctx
      unknown_guid = :crypto.strong_rand_bytes(16)

      assert {:error, :not_found} = OwnershipVoucher.delete(realm_name, unknown_guid)
    end
  end

  describe "decode_cbor/1" do
    test "decodes a valid cbor ownership voucher" do
      voucher = Helpers.sample_cbor_voucher()

      assert {:ok, voucher} = OwnershipVoucherCore.decode_cbor(voucher)
      assert is_struct(voucher, OwnershipVoucherCore)
      assert is_binary(voucher.cert_chain |> hd())
      assert is_struct(voucher.hmac, Hash)
      assert is_struct(voucher.header, Header)
      assert is_struct(voucher.header.cert_chain_hash, Hash)
      assert is_struct(voucher.header.public_key, PublicKey)
      assert is_binary(voucher.header.guid)
      assert voucher.protocol_version == voucher.header.protocol_version
      assert {:ok, _} = Sign1.decode(voucher.entries |> hd())
    end
  end
end
