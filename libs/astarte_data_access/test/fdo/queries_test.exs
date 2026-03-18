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
  alias Astarte.DataAccess.FDO.Queries
  alias Astarte.DataAccess.FDO.TO2Session

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
  defp sample_private_key, do: :crypto.strong_rand_bytes(64)

  describe "ownership voucher" do
    test "create and get voucher data" do
      guid = random_guid()
      voucher = sample_voucher()
      key = sample_private_key()

      assert {:ok, _} = Queries.create_ownership_voucher(@realm, guid, voucher, key, 3600)
      assert {:ok, ^voucher} = Queries.get_ownership_voucher(@realm, guid)
    end

    test "create and get owner private key" do
      guid = random_guid()
      voucher = sample_voucher()
      key = sample_private_key()

      assert {:ok, _} = Queries.create_ownership_voucher(@realm, guid, voucher, key, 3600)
      assert {:ok, ^key} = Queries.get_owner_private_key(@realm, guid)
    end

    test "get voucher returns error when not found" do
      guid = random_guid()
      assert {:error, _} = Queries.get_ownership_voucher(@realm, guid)
    end

    test "delete ownership voucher" do
      guid = random_guid()
      voucher = sample_voucher()
      key = sample_private_key()

      assert {:ok, _} = Queries.create_ownership_voucher(@realm, guid, voucher, key, 3600)
      assert {:ok, _} = Queries.delete_ownership_voucher(@realm, guid)
      assert {:error, _} = Queries.get_ownership_voucher(@realm, guid)
    end

    test "replace ownership voucher" do
      guid = random_guid()
      old_voucher = sample_voucher()
      new_voucher = sample_voucher()
      key = sample_private_key()

      assert {:ok, _} = Queries.create_ownership_voucher(@realm, guid, old_voucher, key, 3600)
      assert {:ok, _} = Queries.replace_ownership_voucher(@realm, guid, new_voucher, key, 3600)
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

    test "session_add_replacement_info" do
      guid = random_guid()
      replacement_guid = random_guid()

      assert :ok = Queries.store_session(@realm, guid, %TO2Session{guid: guid})

      assert :ok =
               Queries.session_add_replacement_info(
                 @realm,
                 guid,
                 replacement_guid,
                 nil,
                 nil,
                 nil
               )

      assert {:ok, fetched} = Queries.fetch_session(@realm, guid)
      assert fetched.replacement_guid == replacement_guid
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
end
