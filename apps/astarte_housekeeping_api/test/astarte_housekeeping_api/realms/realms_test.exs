#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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
  use Astarte.Housekeeping.API.DataCase

  alias Astarte.Housekeeping.API.Realms

  describe "realms" do
    alias Astarte.Housekeeping.API.Realms.Realm

    @pubkey """
    -----BEGIN PUBLIC KEY-----
    MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE6ssZpULEsn+wSQdc+DI2+4aj98a1hDKM
    +bxRibfFC0G6SugduGzqIACSdIiLEn4Nubx2jt4tHDpel0BIrYKlCw==
    -----END PUBLIC KEY-----
    """
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

    @valid_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      device_registration_limit: 42,
      datastream_maximum_storage_retention: 42
    }
    @device_registration_limit_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      device_registration_limit: 10
    }
    @invalid_attrs %{}
    @invalid_update_attrs %{jwt_public_key_pem: @malformed_pubkey}
    @explicit_replication_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      replication_factor: 3
    }
    @network_topology_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      replication_class: "NetworkTopologyStrategy",
      datacenter_replication_factors: %{"dc1" => 2, "dc2" => 1}
    }
    @update_attrs %{jwt_public_key_pem: @update_pubkey}
    @invalid_name_attrs %{realm_name: "0invalid", jwt_public_key_pem: @pubkey}
    @invalid_pubkey_attrs %{realm_name: "valid", jwt_public_key_pem: "invalid"}
    @invalid_replication_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      replication_factor: "invalid"
    }
    @invalid_replication_class_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      replication_class: "invalid"
    }
    @invalid_simple_replication_class_with_datacenter_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      replication_class: "SimpleStrategy",
      datacenter_replication_factors: %{"dc1" => 2}
    }
    @empty_datacenter_replication_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      replication_class: "NetworkTopologyStrategy",
      datacenter_replication_factors: %{}
    }
    @less_than_zero_datacenter_replication_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      replication_class: "NetworkTopologyStrategy",
      datacenter_replication_factors: %{"dc1" => -2}
    }
    @invalid_datacenter_replication_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      replication_class: "NetworkTopologyStrategy",
      datacenter_replication_factors: %{"dc1" => "invalid"}
    }
    @invalid_network_replication_class_with_no_datacenter_attrs %{
      realm_name: "mytestrealm",
      jwt_public_key_pem: @pubkey,
      replication_class: "NetworkTopologyStrategy"
    }
    @malformed_pubkey_attrs %{realm_name: "valid", jwt_public_key_pem: @malformed_pubkey}
    @empty_name_attrs %{realm_name: "", jwt_public_key_pem: @pubkey}
    @empty_pubkey_attrs %{realm_name: "valid", jwt_public_key_pem: nil}
    @non_existing "non_existing_realm"

    def realm_fixture(attrs \\ %{}) do
      {:ok, realm} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Realms.create_realm()

      realm
    end

    test "list_realms/0 returns all realms" do
      %Realm{realm_name: realm_name} = realm_fixture()
      assert Realms.list_realms() == [%Realm{realm_name: realm_name}]
    end

    test "get_realm/1 returns the realm with given id" do
      realm = realm_fixture()
      assert Realms.get_realm(realm.realm_name) == {:ok, realm}
    end

    test "get_realm/1 returns :realm_not_found with unexisting realm" do
      assert Realms.get_realm(@non_existing) == {:error, :realm_not_found}
    end

    test "create_realm/1 with valid data creates a realm" do
      assert {:ok, %Realm{} = _realm} = Realms.create_realm(@valid_attrs)
      assert {:ok, %Realm{} = _realm} = Realms.create_realm(@explicit_replication_attrs)
      assert {:ok, %Realm{} = _realm} = Realms.create_realm(@network_topology_attrs)
    end

    test "create_realm/1 with invalid data returns error changeset" do
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

    test "create_realm/1 with empty required data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@empty_name_attrs)
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@empty_pubkey_attrs)
    end

    test "update_realm/2 with valid data updates the realm" do
      %Realm{realm_name: realm_name} = realm = realm_fixture()

      assert {:ok, realm} = Realms.update_realm(realm_name, @update_attrs)

      assert %Realm{
               realm_name: "mytestrealm",
               jwt_public_key_pem: @update_pubkey
             } = realm
    end

    test "update_realm/2 with valid data and device registration limit set to a valid value updates the realm" do
      %Realm{realm_name: realm_name} = realm = realm_fixture()
      limit = 10
      update_attrs = Map.put(@update_attrs, :device_registration_limit, limit)
      assert {:ok, realm} = Realms.update_realm(realm_name, update_attrs)

      assert %Realm{
               realm_name: "mytestrealm",
               jwt_public_key_pem: @update_pubkey,
               device_registration_limit: ^limit
             } = realm
    end

    test "update_realm/2 with device registration limit set to :unset removes the limit" do
      %Realm{realm_name: realm_name, device_registration_limit: device_registration_limit} =
        realm = realm_fixture()

      assert device_registration_limit != nil
      update_attrs = Map.put(@update_attrs, :device_registration_limit, :unset)
      assert {:ok, realm} = Realms.update_realm(realm_name, update_attrs)

      assert %Realm{
               realm_name: "mytestrealm",
               jwt_public_key_pem: @update_pubkey,
               device_registration_limit: nil
             } = realm
    end

    test "update_realm/2 with device registration limit set to an invalid value fails" do
      %Realm{realm_name: realm_name} = realm = realm_fixture()
      update_attrs = Map.put(@update_attrs, :device_registration_limit, -10)
      assert {:error, %Ecto.Changeset{}} = Realms.update_realm(realm_name, update_attrs)
    end

    test "update_realm/2 with valid data and datastream maximum storage retention set to a valid value updates the realm" do
      %Realm{realm_name: realm_name} = realm_fixture()
      retention = 10
      update_attrs = Map.put(@update_attrs, :datastream_maximum_storage_retention, retention)
      assert {:ok, realm} = Realms.update_realm(realm_name, update_attrs)

      assert %Realm{
               realm_name: "mytestrealm",
               jwt_public_key_pem: @update_pubkey,
               datastream_maximum_storage_retention: ^retention
             } = realm
    end

    test "update_realm/2 with datastream maximum storage retention set to :unset removes the limit" do
      %Realm{realm_name: realm_name, datastream_maximum_storage_retention: retention} =
        realm_fixture()

      assert retention != nil
      update_attrs = Map.put(@update_attrs, :datastream_maximum_storage_retention, :unset)
      assert {:ok, realm} = Realms.update_realm(realm_name, update_attrs)

      assert %Realm{
               realm_name: "mytestrealm",
               jwt_public_key_pem: @update_pubkey,
               datastream_maximum_storage_retention: nil
             } = realm
    end

    test "update_realm/2 with datastream maximum storage retention set to an invalid value fails" do
      %Realm{realm_name: realm_name} = realm_fixture()
      update_attrs = Map.put(@update_attrs, :datastream_maximum_storage_retention, -10)
      assert {:error, %Ecto.Changeset{}} = Realms.update_realm(realm_name, update_attrs)
    end

    test "update_realm/2 with invalid data returns error changeset" do
      %Realm{realm_name: realm_name} = realm = realm_fixture()
      assert {:error, %Ecto.Changeset{}} = Realms.update_realm(realm_name, @invalid_update_attrs)
    end

    @tag :wip
    test "delete_realm/1 deletes the realm" do
      realm = realm_fixture()
      assert {:ok, %Realm{}} = Realms.delete_realm(realm)
      assert_raise Ecto.NoResultsError, fn -> Realms.get_realm!(realm.id) end
    end

    @tag :wip
    test "change_realm/1 returns a realm changeset" do
      realm = realm_fixture()
      assert %Ecto.Changeset{} = Realms.change_realm(realm)
    end
  end
end
