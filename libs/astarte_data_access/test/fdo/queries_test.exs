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

  alias Astarte.Core.Device
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
    setup :setup_voucher

    test "create and get voucher data" do
      guid = random_guid()
      device_id = Device.random_device_id()
      voucher = sample_voucher()

      ownership_voucher = %OwnershipVoucher{
        guid: guid,
        device_id: device_id,
        voucher_data: voucher,
        key_name: "test_key_name",
        key_algorithm: :es256
      }

      assert :ok = Queries.create_ownership_voucher(ownership_voucher)

      assert {:ok, %OwnershipVoucher{voucher_data: ^voucher}} =
               Queries.fetch_ownership_voucher(guid)
    end

    test "get voucher returns error when not found" do
      guid = random_guid()
      assert {:error, _} = Queries.fetch_ownership_voucher(guid)
    end

    test "delete ownership voucher" do
      guid = random_guid()
      voucher = sample_voucher()

      voucher = %OwnershipVoucher{
        guid: guid,
        voucher_data: voucher,
        key_name: "test_key_name",
        key_algorithm: :es256,
        realm: @realm
      }

      :ok = Queries.create_ownership_voucher(voucher)
      assert :ok = Queries.delete_ownership_voucher(guid)
      assert {:error, _} = Queries.fetch_ownership_voucher(guid)
    end

    test "delete ownership voucher succeeds when it is already gone" do
      guid = random_guid()

      assert {:error, :not_found} = Queries.fetch_ownership_voucher(guid)
      assert :ok = Queries.delete_ownership_voucher(guid)
    end

    test "replace/reupload ownership voucher attempt is rejected" do
      voucher_attrs = %OwnershipVoucher{
        guid: random_guid(),
        voucher_data: sample_voucher(),
        key_name: "test_key_name",
        key_algorithm: :es256
      }

      assert :ok = Queries.create_ownership_voucher(voucher_attrs)
      assert {:error, :duplicated_voucher_guid} = Queries.create_ownership_voucher(voucher_attrs)
    end
  end

  describe "fetch_device_id_and_ownership_voucher_and_realm/1" do
    setup :setup_voucher

    test "returns the voucher and the device_id", context do
      %{realm_name: realm_name, guid: guid, device_id: device_id, voucher_data: voucher_data} =
        context

      assert Queries.fetch_device_id_and_ownership_voucher_and_realm(guid) ==
               {:ok, {realm_name, device_id, voucher_data}}
    end

    test "returns :not_found for invalid guid" do
      assert Queries.fetch_device_id_and_ownership_voucher_and_realm(random_guid()) ==
               {:error, :not_found}
    end
  end

  describe "session" do
    test "store, fetch, delete session" do
      guid = random_guid()
      session = %TO2Session{guid: guid, nonce: :crypto.strong_rand_bytes(16), realm: @realm}

      assert :ok = Queries.store_session(session)
      assert {:ok, fetched} = Queries.fetch_session(guid)
      assert fetched.guid == guid
      assert Queries.delete_session(guid) == :ok
      assert {:error, _} = Queries.fetch_session(guid)
    end

    test "fetch session returns error when not found" do
      guid = random_guid()
      assert {:error, _} = Queries.fetch_session(guid)
    end

    test "add session secret" do
      guid = random_guid()
      session = %TO2Session{guid: guid, realm: @realm}
      secret = :crypto.strong_rand_bytes(32)

      assert :ok = Queries.store_session(session)
      assert :ok = Queries.add_session_secret(guid, secret)
      assert {:ok, fetched} = Queries.fetch_session(guid)
      assert fetched.secret == secret
    end

    test "session_add_setup_dv_nonce" do
      guid = random_guid()
      nonce = :crypto.strong_rand_bytes(16)

      assert :ok = Queries.store_session(%TO2Session{guid: guid, realm: @realm})
      assert :ok = Queries.session_add_setup_dv_nonce(guid, nonce)
      assert {:ok, fetched} = Queries.fetch_session(guid)
      assert fetched.setup_dv_nonce == nonce
    end

    test "session_update_device_id" do
      guid = random_guid()
      device_id = :crypto.strong_rand_bytes(16)

      assert :ok = Queries.store_session(%TO2Session{guid: guid, realm: @realm})
      assert :ok = Queries.session_update_device_id(guid, device_id)
      assert {:ok, fetched} = Queries.fetch_session(guid)
      assert fetched.device_id == device_id
    end

    test "add_session_max_owner_service_info_size" do
      guid = random_guid()

      assert :ok = Queries.store_session(%TO2Session{guid: guid, realm: @realm})
      assert :ok = Queries.add_session_max_owner_service_info_size(guid, 1024)
      assert {:ok, fetched} = Queries.fetch_session(guid)
      assert fetched.max_owner_service_info_size == 1024
    end

    test "session_update_last_chunk_sent" do
      guid = random_guid()

      assert :ok = Queries.store_session(%TO2Session{guid: guid, realm: @realm})
      assert :ok = Queries.session_update_last_chunk_sent(guid, 5)
      assert {:ok, fetched} = Queries.fetch_session(guid)
      assert fetched.last_chunk_sent == 5
    end

    test "session_add_device_service_info" do
      guid = random_guid()
      service_info = %{{"module", "msg"} => <<1, 2, 3>>}

      assert :ok = Queries.store_session(%TO2Session{guid: guid, realm: @realm})
      assert :ok = Queries.session_add_device_service_info(guid, service_info)
      assert {:ok, fetched} = Queries.fetch_session(guid)
      assert fetched.device_service_info == service_info
    end

    test "session_add_owner_service_info" do
      guid = random_guid()
      owner_service_info = [:crypto.strong_rand_bytes(16), :crypto.strong_rand_bytes(16)]

      assert :ok = Queries.store_session(%TO2Session{guid: guid, realm: @realm})
      assert :ok = Queries.session_add_owner_service_info(guid, owner_service_info)
      assert {:ok, fetched} = Queries.fetch_session(guid)
      assert fetched.owner_service_info == owner_service_info
    end
  end

  describe "list_ownership_vouchers/1" do
    setup :setup_voucher

    test "returns the list of vouchers", %{guid: guid} do
      assert {:ok, vouchers} = Queries.list_ownership_vouchers(@realm)
      assert Enum.all?(vouchers, &is_struct(&1, OwnershipVoucher))
      assert Enum.find(vouchers, &(&1.guid == guid))
    end
  end

  describe "mark_device_as_claimed/2" do
    setup :setup_voucher

    test "updates the status of the ownership voucher", %{guid: guid} do
      opts = [prefix: Realm.astarte_keyspace_name()]
      assert %{status: :created} = Repo.get(OwnershipVoucher, guid, opts)
      assert :ok == Queries.mark_voucher_as_claimed(guid)
      assert %{status: :claimed} = Repo.get(OwnershipVoucher, guid, opts)
    end

    test "clears the expiry of the ownership voucher", %{guid: guid} do
      opts = [prefix: Realm.astarte_keyspace_name()]

      expiry =
        DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:millisecond)

      assert :ok == Queries.update_voucher_expiry(guid, expiry)
      assert %{expiry: ^expiry} = Repo.get(OwnershipVoucher, guid, opts)

      assert :ok == Queries.mark_voucher_as_claimed(guid)
      assert %{expiry: nil} = Repo.get(OwnershipVoucher, guid, opts)
    end
  end

  describe "update_voucher_expiry/2" do
    setup :setup_voucher

    test "updates the expiry of the ownership voucher", %{guid: guid} do
      opts = [prefix: Realm.astarte_keyspace_name()]

      expiry =
        DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:millisecond)

      assert %{expiry: nil} = Repo.get(OwnershipVoucher, guid, opts)
      assert :ok == Queries.update_voucher_expiry(guid, expiry)
      assert %{expiry: ^expiry} = Repo.get(OwnershipVoucher, guid, opts)
    end
  end

  describe "get_owner_key_params/1" do
    setup :setup_ov_entry

    test "returns a map with key name and algorithm", context do
      %{guid: guid, key_name: key_name, key_algorithm: key_algorithm} = context
      assert {:ok, result} = Queries.get_owner_key_params(guid)
      assert %{name: key_name, algorithm: key_algorithm} == result
    end

    test "returns :not_found when the guid is not found", context do
      %{replacement_guid: non_existing_guid} = context
      assert {:error, :not_found} = Queries.get_owner_key_params(non_existing_guid)
    end
  end

  describe "get_replacement_data/1" do
    setup :setup_ov_entry

    test "returns replacement data", context do
      %{
        guid: guid,
        replacement_guid: replacement_guid,
        replacement_rendezvous_info: replacement_rendezvous_info,
        replacement_public_key: replacement_public_key
      } = context

      assert {:ok, result} = Queries.get_replacement_data(guid)

      assert %{
               replacement_guid: replacement_guid,
               replacement_rendezvous_info: replacement_rendezvous_info,
               replacement_public_key: replacement_public_key
             } == result
    end

    test "returns :not_found when the guid is not found", context do
      %{replacement_guid: non_existing_guid} = context
      assert {:error, :not_found} = Queries.get_owner_key_params(non_existing_guid)
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
      realm: @realm,
      replacement_guid: replacement_guid,
      replacement_rendezvous_info: replacement_rendezvous_info,
      replacement_public_key: replacement_public_key
    }

    on_exit(fn ->
      Repo.delete(ov, prefix: Realm.astarte_keyspace_name())
    end)

    Repo.insert!(ov, prefix: Realm.astarte_keyspace_name())

    %{
      guid: guid,
      replacement_guid: replacement_guid,
      replacement_rendezvous_info: replacement_rendezvous_info,
      replacement_public_key: replacement_public_key,
      key_name: key_name,
      key_algorithm: key_algorithm
    }
  end

  defp setup_voucher(_context) do
    guid = :crypto.strong_rand_bytes(16)
    device_id = Device.random_device_id()
    voucher_data = sample_voucher()

    on_exit(fn -> Queries.delete_ownership_voucher(guid) end)

    voucher =
      %OwnershipVoucher{
        device_id: device_id,
        guid: guid,
        key_name: "key",
        key_algorithm: :es256,
        voucher_data: voucher_data,
        realm: @realm
      }

    :ok = Queries.create_ownership_voucher(voucher)

    %{
      realm_name: @realm,
      guid: guid,
      device_id: device_id,
      voucher: voucher,
      voucher_data: voucher_data
    }
  end
end
