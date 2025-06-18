#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.Housekeeping.API.RealmsTest do
  use Astarte.Housekeeping.API.DataCase, async: true
  use ExUnitProperties
  use Mimic

  import Astarte.Housekeeping.API.Fixtures.Realm

  alias Astarte.Core.Generators.Realm, as: GeneratorsRealm
  alias Astarte.Housekeeping.API.Config
  alias Astarte.Housekeeping.API.Helpers.Database
  alias Astarte.Housekeeping.API.Realms
  alias Astarte.Housekeeping.API.Realms.Realm
  alias Astarte.Housekeeping.API.Realms.Queries

  @malformed_pubkey """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYAoDQgAE6ssZpw4aj98a1hDKM
    +bxRibfFC0G6SugduGzqIACSdIiLEn4Nubx2jt4tHDpel0BIrYKlCw==
  -----END PUBLIC KEY-----
  """
  @update_pubkey """
  -----BEGIN PUBLIC KEY-----
  MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEat8cZJ77myME8YQYfVkxOz39Wrq9
  3FYHyYudzQKa11c55Z6ZZaw2H+nUkQl1/jqfHTrqMSiOP4TTf0oTYLWKfg==
  -----END PUBLIC KEY-----
  """

  @invalid_update_attrs %{jwt_public_key_pem: @malformed_pubkey}
  @update_attrs %{jwt_public_key_pem: @update_pubkey}
  @invalid_name_attrs %{realm_name: "0invalid", jwt_public_key_pem: pubkey()}
  @invalid_pubkey_attrs %{realm_name: "valid", jwt_public_key_pem: "invalid"}
  @invalid_replication_attrs %{
    realm_name: "mytestrealm",
    jwt_public_key_pem: pubkey(),
    replication_factor: "invalid"
  }
  @invalid_replication_class_attrs %{
    realm_name: "mytestrealm",
    jwt_public_key_pem: pubkey(),
    replication_class: "invalid"
  }
  @invalid_simple_replication_class_with_datacenter_attrs %{
    realm_name: "mytestrealm",
    jwt_public_key_pem: pubkey(),
    replication_class: "SimpleStrategy",
    datacenter_replication_factors: %{"dc1" => 2}
  }
  @empty_datacenter_replication_attrs %{
    realm_name: "mytestrealm",
    jwt_public_key_pem: pubkey(),
    replication_class: "NetworkTopologyStrategy",
    datacenter_replication_factors: %{}
  }
  @less_than_zero_datacenter_replication_attrs %{
    realm_name: "mytestrealm",
    jwt_public_key_pem: pubkey(),
    replication_class: "NetworkTopologyStrategy",
    datacenter_replication_factors: %{"dc1" => -2}
  }
  @invalid_datacenter_replication_attrs %{
    realm_name: "mytestrealm",
    jwt_public_key_pem: pubkey(),
    replication_class: "NetworkTopologyStrategy",
    datacenter_replication_factors: %{"dc1" => "invalid"}
  }
  @invalid_network_replication_class_with_no_datacenter_attrs %{
    realm_name: "mytestrealm",
    jwt_public_key_pem: pubkey(),
    replication_class: "NetworkTopologyStrategy"
  }
  @malformed_pubkey_attrs %{realm_name: "valid", jwt_public_key_pem: @malformed_pubkey}
  @empty_name_attrs %{realm_name: "", jwt_public_key_pem: pubkey()}
  @empty_pubkey_attrs %{realm_name: "valid", jwt_public_key_pem: nil}
  @non_existing "nonexistingrealm"

  setup_all do
    Config.put_enable_realm_deletion(true)
  end

  setup %{astarte_instance_id: astarte_instance_id} do
    realm_name = "realm#{System.unique_integer([:positive])}"

    on_exit(fn ->
      Database.setup_database_access(astarte_instance_id)
      Database.teardown_realm_keyspace(realm_name)
    end)

    %{realm_name: realm_name}
  end

  describe "property based tests" do
    property "realm lifecycle operations work as expected" do
      check all(name <- GeneratorsRealm.realm_name(), max_runs: 5) do
        # Test realm creation
        realm = realm_fixture(%{realm_name: name})

        # Test fetching the created realm
        assert {:ok, realm} == Realms.get_realm(name)
        assert realm.realm_name == name

        # Test deleting the realm
        assert :ok = Realms.delete_realm(name)
        assert {:error, :realm_not_found} == Realms.get_realm(name)
      end
    end
  end

  describe "realms fetching" do
    test "list_realms/0 contains added realm", %{realm_name: realm_name} do
      realm_fixture(%{realm_name: realm_name})
      assert %Realm{realm_name: realm_name} in Realms.list_realms()
    end

    test "list_realms/0 doesn't contain nonexisting realm" do
      refute %Realm{realm_name: @non_existing} in Realms.list_realms()
    end

    test "get_realm/1 returns :realm_not_found with unexisting realm" do
      assert Realms.get_realm(@non_existing) == {:error, :realm_not_found}
    end
  end

  describe "realms creation" do
    test "succeeds using a synchronous call", %{realm_name: realm_name} do
      attrs = %{
        realm_name: realm_name,
        jwt_public_key_pem: pubkey(),
        device_registration_limit: 42,
        datastream_maximum_storage_retention: 42
      }

      assert {:ok, %Realm{} = _realm} = Realms.create_realm(attrs, async_operation: false)
    end

    test "fails to create a realm with duplicate name", %{realm_name: realm_name} do
      attrs = %{
        realm_name: realm_name,
        jwt_public_key_pem: pubkey(),
        device_registration_limit: 42,
        datastream_maximum_storage_retention: 42
      }

      assert {:ok, %Realm{} = _realm} = Realms.create_realm(attrs)
      assert {:error, :database_error} = Realms.create_realm(attrs)
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@invalid_name_attrs)
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@invalid_pubkey_attrs)
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@malformed_pubkey_attrs)
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@invalid_replication_attrs)
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@invalid_replication_class_attrs)

      assert {:error, %Ecto.Changeset{}} =
               Realms.create_realm(@empty_datacenter_replication_attrs)

      assert {:error, %Ecto.Changeset{}} =
               Realms.create_realm(@less_than_zero_datacenter_replication_attrs)

      assert {:error, %Ecto.Changeset{}} =
               Realms.create_realm(@invalid_datacenter_replication_attrs)

      assert {:error, %Ecto.Changeset{}} =
               Realms.create_realm(@invalid_simple_replication_class_with_datacenter_attrs)

      assert {:error, %Ecto.Changeset{}} =
               Realms.create_realm(@invalid_network_replication_class_with_no_datacenter_attrs)
    end

    test "with empty required data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@empty_name_attrs)
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@empty_pubkey_attrs)
    end
  end

  describe "realms update" do
    test "with valid jwt updates the realm" do
      %Realm{realm_name: realm_name} = realm_fixture()

      assert {:ok,
              %Realm{
                realm_name: ^realm_name,
                jwt_public_key_pem: @update_pubkey
              }} = Realms.update_realm(realm_name, @update_attrs)
    end

    test "fails when the realm doesn't exist" do
      assert {:error, :realm_not_found} = Realms.update_realm(@non_existing, @update_attrs)
    end

    test "fails with an invalid realm name" do
      assert {:error, :realm_not_allowed} = Realms.update_realm("system", @update_attrs)
    end

    test "with valid data and device registration limit set to a valid value updates the realm" do
      limit = 10
      update_attrs = Map.put(@update_attrs, :device_registration_limit, limit)

      %Realm{realm_name: realm_name} = realm_fixture()

      assert {:ok,
              %Realm{
                realm_name: ^realm_name,
                jwt_public_key_pem: @update_pubkey,
                device_registration_limit: ^limit
              }} = Realms.update_realm(realm_name, update_attrs)
    end

    test "with device registration limit set to :unset removes the limit" do
      %Realm{realm_name: realm_name, device_registration_limit: device_registration_limit} =
        realm_fixture()

      update_attrs = Map.put(@update_attrs, :device_registration_limit, :unset)
      assert device_registration_limit != nil

      assert {:ok,
              %Realm{
                realm_name: ^realm_name,
                jwt_public_key_pem: @update_pubkey,
                device_registration_limit: nil
              }} = Realms.update_realm(realm_name, update_attrs)
    end

    test "with device registration limit set to an invalid value fails" do
      update_attrs = Map.put(@update_attrs, :device_registration_limit, -10)

      %Realm{realm_name: realm_name} = realm_fixture()

      assert {:error, %Ecto.Changeset{}} = Realms.update_realm(realm_name, update_attrs)
    end

    test "with valid data and datastream maximum storage retention set to a valid value updates the realm" do
      retention = 10
      update_attrs = Map.put(@update_attrs, :datastream_maximum_storage_retention, retention)

      %Realm{realm_name: realm_name} = realm_fixture()

      assert {:ok,
              %Realm{
                realm_name: ^realm_name,
                jwt_public_key_pem: @update_pubkey,
                datastream_maximum_storage_retention: ^retention
              }} = Realms.update_realm(realm_name, update_attrs)
    end

    test "with datastream maximum storage retention set to :unset removes the limit" do
      %Realm{realm_name: realm_name, datastream_maximum_storage_retention: retention} =
        realm_fixture()

      assert retention != nil

      update_attrs = Map.put(@update_attrs, :datastream_maximum_storage_retention, :unset)

      assert {:ok,
              %Realm{
                realm_name: ^realm_name,
                jwt_public_key_pem: @update_pubkey,
                datastream_maximum_storage_retention: nil
              }} = Realms.update_realm(realm_name, update_attrs)
    end

    test "with datastream maximum storage retention set to an invalid value fails" do
      %Realm{realm_name: realm_name} = realm_fixture()
      update_attrs = Map.put(@update_attrs, :datastream_maximum_storage_retention, -10)
      assert {:error, %Ecto.Changeset{}} = Realms.update_realm(realm_name, update_attrs)
    end

    test "with invalid data returns error changeset" do
      %Realm{realm_name: realm_name} = realm_fixture()
      assert {:error, %Ecto.Changeset{}} = Realms.update_realm(realm_name, @invalid_update_attrs)
    end
  end

  describe "delete_realm/2" do
    setup %{realm_name: realm_name} do
      Database.setup(realm_name)
    end

    test "succeeds using a synchronous call", %{realm_name: realm_name} do
      assert :ok = Realms.delete_realm(realm_name, [])
    end

    test "succeeds using a asynchronous call", %{realm_name: realm_name} do
      assert :ok = Realms.delete_realm(realm_name, async: true)
    end

    test "returns error when trying to delete a realm while deletion is disabled", %{
      realm_name: realm_name
    } do
      Mimic.stub(Config, :enable_realm_deletion!, fn -> false end)

      assert {:error, :realm_deletion_disabled} = Realms.delete_realm(realm_name, [])
    end

    test "returns error when deleting a realm with connected devices", %{realm_name: realm_name} do
      Mimic.stub(Queries, :delete_realm, fn _, _ -> {:error, :connected_devices_present} end)

      assert {:error, :connected_devices_present} = Realms.delete_realm(realm_name, async: true)
    end

    test "deletions returns an error", %{realm_name: realm_name} do
      Xandra.Cluster |> stub(:run, fn _, _, _ -> {:error, "generic error"} end)

      assert {:error, "generic error"} = Realms.delete_realm(realm_name)
    end
  end
end
