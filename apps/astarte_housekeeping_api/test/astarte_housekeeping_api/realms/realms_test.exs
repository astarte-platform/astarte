#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
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
    @valid_attrs %{realm_name: "mytestrealm", jwt_public_key_pem: @pubkey}
    @explicit_replication_attrs %{realm_name: "mytestrealm", jwt_public_key_pem: @pubkey, replication_factor: 3}
    @update_attrs %{}
    @invalid_name_attrs %{realm_name: "0invalid", jwt_public_key_pem: @pubkey}
    @invalid_pubkey_attrs %{realm_name: "valid", jwt_public_key_pem: "invalid"}
    @invalid_replication_attrs %{realm_name: "mytestrealm", jwt_public_key_pem: @pubkey, replication_factor: "invalid"}
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
    end

    test "create_realm/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@invalid_name_attrs)
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@invalid_pubkey_attrs)
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@malformed_pubkey_attrs)
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@invalid_replication_attrs)
    end

    test "create_realm/1 with empty required data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@empty_name_attrs)
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@empty_pubkey_attrs)
    end

    @tag :wip
    test "update_realm/2 with valid data updates the realm" do
      realm = realm_fixture()
      assert {:ok, realm} = Realms.update_realm(realm, @update_attrs)
      assert %Realm{} = realm
    end

    @tag :wip
    test "update_realm/2 with invalid data returns error changeset" do
      realm = realm_fixture()
      assert {:error, %Ecto.Changeset{}} = Realms.update_realm(realm, @invalid_attrs)
      assert realm == Realms.get_realm!(realm.id)
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
