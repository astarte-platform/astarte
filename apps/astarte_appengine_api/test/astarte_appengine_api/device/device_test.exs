defmodule AstarteAppengineApi.DeviceTest do
  use AstarteAppengineApi.DataCase

  alias AstarteAppengineApi.Device

  describe "interfaces" do
    alias AstarteAppengineApi.Device.InterfaceValues

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def interface_values_fixture(attrs \\ %{}) do
      {:ok, interface_values} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Device.create_interface_values()

      interface_values
    end

    test "list_interfaces/0 returns all interfaces" do
      interface_values = interface_values_fixture()
      assert Device.list_interfaces() == [interface_values]
    end

    test "get_interface_values!/1 returns the interface_values with given id" do
      interface_values = interface_values_fixture()
      assert Device.get_interface_values!(interface_values.id) == interface_values
    end

    test "create_interface_values/1 with valid data creates a interface_values" do
      assert {:ok, %InterfaceValues{} = interface_values} = Device.create_interface_values(@valid_attrs)
    end

    test "create_interface_values/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Device.create_interface_values(@invalid_attrs)
    end

    test "update_interface_values/2 with valid data updates the interface_values" do
      interface_values = interface_values_fixture()
      assert {:ok, interface_values} = Device.update_interface_values(interface_values, @update_attrs)
      assert %InterfaceValues{} = interface_values
    end

    test "update_interface_values/2 with invalid data returns error changeset" do
      interface_values = interface_values_fixture()
      assert {:error, %Ecto.Changeset{}} = Device.update_interface_values(interface_values, @invalid_attrs)
      assert interface_values == Device.get_interface_values!(interface_values.id)
    end

    test "delete_interface_values/1 deletes the interface_values" do
      interface_values = interface_values_fixture()
      assert {:ok, %InterfaceValues{}} = Device.delete_interface_values(interface_values)
      assert_raise Ecto.NoResultsError, fn -> Device.get_interface_values!(interface_values.id) end
    end

    test "change_interface_values/1 returns a interface_values changeset" do
      interface_values = interface_values_fixture()
      assert %Ecto.Changeset{} = Device.change_interface_values(interface_values)
    end
  end
end
