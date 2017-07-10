defmodule Astarte.RealmManagement.API.InterfacesTest do
  use Astarte.RealmManagement.API.DataCase

  alias Astarte.RealmManagement.API.Interfaces

  describe "interfaces" do
    alias Astarte.RealmManagement.API.Interfaces.Interface

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def interface_fixture(attrs \\ %{}) do
      {:ok, interface} =
        attrs
        |> Enum.into(@valid_attrs)
        |> RealmManagement.API.Interfaces.create_interface()

      interface
    end

    test "list_interfaces/0 returns all interfaces" do
      interface = interface_fixture()
      assert RealmManagement.API.Interfaces.list_interfaces() == [interface]
    end

    test "get_interface!/1 returns the interface with given id" do
      interface = interface_fixture()
      assert RealmManagement.API.Interfaces.get_interface!(interface.id) == interface
    end

    test "create_interface/1 with valid data creates a interface" do
      assert {:ok, %Interface{} = interface} = RealmManagement.API.Interfaces.create_interface(@valid_attrs)
    end

    test "create_interface/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = RealmManagement.API.Interfaces.create_interface(@invalid_attrs)
    end

    test "update_interface/2 with valid data updates the interface" do
      interface = interface_fixture()
      assert {:ok, interface} = RealmManagement.API.Interfaces.update_interface(interface, @update_attrs)
      assert %Interface{} = interface
    end

    test "update_interface/2 with invalid data returns error changeset" do
      interface = interface_fixture()
      assert {:error, %Ecto.Changeset{}} = RealmManagement.API.Interfaces.update_interface(interface, @invalid_attrs)
      assert interface == RealmManagement.API.Interfaces.get_interface!(interface.id)
    end

    test "delete_interface/1 deletes the interface" do
      interface = interface_fixture()
      assert {:ok, %Interface{}} = RealmManagement.API.Interfaces.delete_interface(interface)
      assert_raise Ecto.NoResultsError, fn -> RealmManagement.API.Interfaces.get_interface!(interface.id) end
    end

    test "change_interface/1 returns a interface changeset" do
      interface = interface_fixture()
      assert %Ecto.Changeset{} = RealmManagement.API.Interfaces.change_interface(interface)
    end
  end
end
