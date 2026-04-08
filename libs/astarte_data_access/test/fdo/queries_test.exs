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

defmodule Astarte.DataAccess.FDO.QueriesTest do
  use ExUnit.Case

  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.FDO.OwnershipVoucher
  alias Astarte.DataAccess.FDO.Queries
  alias Astarte.DataAccess.FDO.TO2Session
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.FDO.Core.OwnershipVoucher.RendezvousInfo
  alias Astarte.FDO.Core.OwnershipVoucher.RendezvousInfo.RendezvousDirective
  alias Astarte.FDO.Core.OwnershipVoucher.RendezvousInfo.RendezvousInstr
  alias Astarte.FDO.Core.PublicKey

  @realm "autotestrealm"

  setup_all do
    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.destroy_local_test_keyspace(conn)
        DatabaseTestHelper.destroy_astarte_keyspace(conn)
      end)
    end)

    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
      DatabaseTestHelper.create_astarte_keyspace(conn)
    end)

    :ok
  end

  defp random_guid, do: :crypto.strong_rand_bytes(16)
  defp sample_voucher, do: :crypto.strong_rand_bytes(32)

  describe "ownership voucher" do
    test "create and get voucher data" do
      guid = random_guid()
      voucher = sample_voucher()

      attrs = %{
        guid: guid,
        voucher_data: voucher,
        key_name: "test_key_name",
        key_algorithm: :es256
      }

      assert {:ok, _} = Queries.create_ownership_voucher(@realm, attrs)
      assert {:ok, ^voucher} = Queries.get_ownership_voucher(@realm, guid)
    end

    test "get voucher returns error when not found" do
      guid = random_guid()
      assert {:error, _} = Queries.get_ownership_voucher(@realm, guid)
    end

    test "delete ownership voucher" do
      guid = random_guid()
      voucher = sample_voucher()

      attrs = %{
        guid: guid,
        voucher_data: voucher,
        key_name: "test_key_name",
        key_algorithm: :es256
      }

      assert {:ok, _} = Queries.create_ownership_voucher(@realm, attrs)
      assert {:ok, _} = Queries.delete_ownership_voucher(@realm, guid)
      assert {:error, _} = Queries.get_ownership_voucher(@realm, guid)
    end

    test "replace ownership voucher" do
      guid = random_guid()
      old_voucher = sample_voucher()
      new_voucher = sample_voucher()

      old_attrs = %{
        guid: guid,
        voucher_data: old_voucher,
        key_name: "test_key_name",
        key_algorithm: :es256
      }

      assert {:ok, _} = Queries.create_ownership_voucher(@realm, old_attrs)

      new_attrs = %{
        guid: guid,
        voucher_data: new_voucher,
        key_name: "test_key_name",
        key_algorithm: :es256
      }

      assert {:ok, _} = Queries.create_ownership_voucher(@realm, new_attrs)

      assert {:ok, ^new_voucher} = Queries.get_ownership_voucher(@realm, guid)
    end
  end

  describe "session" do
    test "store and fetch session" do
      guid = random_guid()
      session = %TO2Session{guid: guid, nonce: :crypto.strong_rand_bytes(16)}

      assert :ok = Queries.store_session(@realm, guid, session)
      assert {:ok, fetched} = Queries.fetch_session(@realm, guid)
      assert fetched.guid == guid
    end

    test "fetch session returns error when not found" do
      guid = random_guid()
      assert {:error, _} = Queries.fetch_session(@realm, guid)
    end

    test "add session secret" do
      guid = random_guid()
      session = %TO2Session{guid: guid}
      secret = :crypto.strong_rand_bytes(32)

      assert :ok = Queries.store_session(@realm, guid, session)
      assert :ok = Queries.add_session_secret(@realm, guid, secret)
      assert {:ok, fetched} = Queries.fetch_session(@realm, guid)
      assert fetched.secret == secret
    end

    test "session_add_setup_dv_nonce" do
      guid = random_guid()
      nonce = :crypto.strong_rand_bytes(16)

      assert :ok = Queries.store_session(@realm, guid, %TO2Session{guid: guid})
      assert :ok = Queries.session_add_setup_dv_nonce(@realm, guid, nonce)
      assert {:ok, fetched} = Queries.fetch_session(@realm, guid)
      assert fetched.setup_dv_nonce == nonce
    end

    test "session_update_device_id" do
      guid = random_guid()
      device_id = :crypto.strong_rand_bytes(16)

      assert :ok = Queries.store_session(@realm, guid, %TO2Session{guid: guid})
      assert :ok = Queries.session_update_device_id(@realm, guid, device_id)
      assert {:ok, fetched} = Queries.fetch_session(@realm, guid)
      assert fetched.device_id == device_id
    end

    test "add_session_max_owner_service_info_size" do
      guid = random_guid()

      assert :ok = Queries.store_session(@realm, guid, %TO2Session{guid: guid})
      assert :ok = Queries.add_session_max_owner_service_info_size(@realm, guid, 1024)
      assert {:ok, fetched} = Queries.fetch_session(@realm, guid)
      assert fetched.max_owner_service_info_size == 1024
    end

    test "session_update_last_chunk_sent" do
      guid = random_guid()

      assert :ok = Queries.store_session(@realm, guid, %TO2Session{guid: guid})
      assert :ok = Queries.session_update_last_chunk_sent(@realm, guid, 5)
      assert {:ok, fetched} = Queries.fetch_session(@realm, guid)
      assert fetched.last_chunk_sent == 5
    end

    test "session_add_device_service_info" do
      guid = random_guid()
      service_info = %{{"module", "msg"} => <<1, 2, 3>>}

      assert :ok = Queries.store_session(@realm, guid, %TO2Session{guid: guid})
      assert :ok = Queries.session_add_device_service_info(@realm, guid, service_info)
      assert {:ok, fetched} = Queries.fetch_session(@realm, guid)
      assert fetched.device_service_info == service_info
    end

    test "session_add_owner_service_info" do
      guid = random_guid()
      owner_service_info = [:crypto.strong_rand_bytes(16), :crypto.strong_rand_bytes(16)]

      assert :ok = Queries.store_session(@realm, guid, %TO2Session{guid: guid})
      assert :ok = Queries.session_add_owner_service_info(@realm, guid, owner_service_info)
      assert {:ok, fetched} = Queries.fetch_session(@realm, guid)
      assert fetched.owner_service_info == owner_service_info
    end
  end

  describe "mark_device_as_claimed/2" do
    setup do
      guid = :crypto.strong_rand_bytes(16)

      on_exit(fn -> Queries.delete_ownership_voucher(@realm, guid) end)

      Queries.create_ownership_voucher(@realm, %{
        guid: guid,
        key_name: "key",
        key_algorithm: :es256,
        voucher_data: <<0>>
      })

      %{guid: guid}
    end

    test "updates the status of the ownership voucher", %{guid: guid} do
      opts = [prefix: Realm.keyspace_name(@realm)]
      assert %{status: :created} = Repo.get(OwnershipVoucher, guid, opts)
      assert :ok == Queries.mark_voucher_as_claimed(@realm, guid)
      assert %{status: :claimed} = Repo.get(OwnershipVoucher, guid, opts)
    end
  end

  describe "remove_device_ttl/2" do
    setup do
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.seed_data(conn)
      end)
    end

    test "re-inserts an existing device without TTL" do
      {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

      assert {:ok, _device} = Queries.remove_device_ttl(@realm, device_id)
    end

    test "returns error for a missing device" do
      missing_id = :crypto.strong_rand_bytes(16)
      assert {:error, :device_not_found} = Queries.remove_device_ttl(@realm, missing_id)
    end
  end

  describe "get_owner_key_params/2" do
    setup :setup_ov_entry

    test "returns a map with key name and algorithm", context do
      %{guid: guid, key_name: key_name, key_algorithm: key_algorithm} = context
      assert {:ok, result} = Queries.get_owner_key_params(@realm, guid)
      assert %{name: key_name, algorithm: key_algorithm} == result
    end

    test "returns :not_found when the guid is not found", context do
      %{replacement_guid: non_existing_guid} = context
      assert {:error, :not_found} = Queries.get_owner_key_params(@realm, non_existing_guid)
    end
  end

  describe "get_replacement_data/2" do
    setup :setup_ov_entry

    test "returns replacement data", context do
      %{
        guid: guid,
        replacement_guid: replacement_guid,
        replacement_rendezvous_info: replacement_rendezvous_info,
        replacement_public_key: replacement_public_key
      } = context

      assert {:ok, result} = Queries.get_replacement_data(@realm, guid)

      assert %{
               replacement_guid: replacement_guid,
               replacement_rendezvous_info: replacement_rendezvous_info,
               replacement_public_key: replacement_public_key
             } == result
    end

    test "returns :not_found when the guid is not found", context do
      %{replacement_guid: non_existing_guid} = context
      assert {:error, :not_found} = Queries.get_owner_key_params(@realm, non_existing_guid)
    end
  end

  defp setup_ov_entry(_context) do
    key_name = "key#{System.unique_integer()}"
    key_algorithm = :es256
    guid = :crypto.strong_rand_bytes(16)
    replacement_guid = :crypto.strong_rand_bytes(16)

    replacement_directive = %RendezvousDirective{
      instructions: [%RendezvousInstr{rv_variable: :dev_only, rv_value: CBOR.encode(true)}]
    }

    replacement_rendezvous_info = %RendezvousInfo{directives: [replacement_directive]}
    replacement_public_key = %PublicKey{type: :secp256r1, encoding: :x509, body: "sample key"}

    ov = %OwnershipVoucher{
      guid: guid,
      key_name: key_name,
      key_algorithm: key_algorithm,
      replacement_guid: replacement_guid,
      replacement_rendezvous_info: replacement_rendezvous_info,
      replacement_public_key: replacement_public_key
    }

    on_exit(fn ->
      Repo.delete(ov, prefix: Realm.keyspace_name(@realm))
    end)

    Repo.insert!(ov, prefix: Realm.keyspace_name(@realm))

    %{
      guid: guid,
      replacement_guid: replacement_guid,
      replacement_rendezvous_info: replacement_rendezvous_info,
      replacement_public_key: replacement_public_key,
      key_name: key_name,
      key_algorithm: key_algorithm
    }
  end
end
