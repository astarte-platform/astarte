defmodule Astarte.Housekeeping.API.RealmsTest do
  use Astarte.Housekeeping.API.DataCase

  alias Astarte.Housekeeping.API.Realms

  describe "realms" do
    alias Astarte.Housekeeping.API.Realms.Realm

    @valid_attrs %{realm_name: "mytestrealm"}
    @update_attrs %{}
    @invalid_attrs %{realm_name: "0invalid"}

    def realm_fixture(attrs \\ %{}) do
      {:ok, realm} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Realms.create_realm()

      realm
    end

    test "list_realms/0 returns all realms" do
      realm = realm_fixture()
      assert Realms.list_realms() == [realm]
    end

    test "get_realm!/1 returns the realm with given id" do
      realm = realm_fixture()
      assert Realms.get_realm!(realm.id) == realm
    end

    test "create_realm/1 with valid data creates a realm" do
      assert {:ok, %Realm{} = realm} = Realms.create_realm(@valid_attrs)
    end

    test "create_realm/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Realms.create_realm(@invalid_attrs)
    end

    test "update_realm/2 with valid data updates the realm" do
      realm = realm_fixture()
      assert {:ok, realm} = Realms.update_realm(realm, @update_attrs)
      assert %Realm{} = realm
    end

    test "update_realm/2 with invalid data returns error changeset" do
      realm = realm_fixture()
      assert {:error, %Ecto.Changeset{}} = Realms.update_realm(realm, @invalid_attrs)
      assert realm == Realms.get_realm!(realm.id)
    end

    test "delete_realm/1 deletes the realm" do
      realm = realm_fixture()
      assert {:ok, %Realm{}} = Realms.delete_realm(realm)
      assert_raise Ecto.NoResultsError, fn -> Realms.get_realm!(realm.id) end
    end

    test "change_realm/1 returns a realm changeset" do
      realm = realm_fixture()
      assert %Ecto.Changeset{} = Realms.change_realm(realm)
    end
  end
end
