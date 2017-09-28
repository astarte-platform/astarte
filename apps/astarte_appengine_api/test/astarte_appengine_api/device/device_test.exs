defmodule Astarte.AppEngine.API.DeviceTest do
  use ExUnit.Case
  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceNotFoundError
  alias Astarte.AppEngine.API.Device.EndpointNotFoundError
  alias Astarte.AppEngine.API.Device.InterfaceNotFoundError
  alias Astarte.AppEngine.API.Device.PathNotFoundError

  setup do
    {:ok, _client} = Astarte.RealmManagement.DatabaseTestHelper.create_test_keyspace()

    on_exit fn ->
      Astarte.RealmManagement.DatabaseTestHelper.destroy_local_test_keyspace()
    end
  end

  test "list_interfaces!/2 returns all interfaces" do
    assert Device.list_interfaces!("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ") == ["com.test.LCDMonitor"]
  end

  test "get_interface_values! returns interfaces values" do
    expected_reply = %{"time" => %{"from" => 8, "to" => 20}, "lcdCommand" => "SWITCH_ON", "weekSchedule" => %{"2" => %{"start" => 12, "stop" => 15}, "3" => %{"start" => 15, "stop" => 16}, "4" => %{"start" => 16, "stop" => 18}}}
    assert Device.get_interface_values!("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.LCDMonitor") == expected_reply

    assert Device.get_interface_values!("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.LCDMonitor", "time") ==  %{"from" => 8, "to" => 20}
    assert Device.get_interface_values!("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.LCDMonitor", "time/from") ==  8

    assert_raise DeviceNotFoundError, fn ->
      Device.get_interface_values!("autotestrealm", "g0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.LCDMonitor", "time/from")
    end

    assert_raise InterfaceNotFoundError, fn ->
      Device.get_interface_values!("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.Missing", "weekSchedule/3/start")
    end

    assert_raise EndpointNotFoundError, fn ->
      Device.get_interface_values!("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.LCDMonitor", "time/missing")
    end

    assert_raise PathNotFoundError, fn ->
      Device.get_interface_values!("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.LCDMonitor", "weekSchedule/9/start")
    end
  end

  test "list_devices/0 returns all devices" do
    #device_status = device_status_fixture()
    #assert AppEngine.API.Device.list_devices() == [device_status]
  end

  test "get_device_status!/1 returns the device_status with given id" do
    #device_status = device_status_fixture()
    #assert AppEngine.API.Device.get_device_status!(device_status.id) == device_status
  end

  test "update_device_status/2 with valid data updates the device_status" do
    #device_status = device_status_fixture()
    #assert {:ok, device_status} = AppEngine.API.Device.update_device_status(device_status, @update_attrs)
    #assert %DeviceStatus{} = device_status
  end

  test "update_device_status/2 with invalid data returns error changeset" do
    #device_status = device_status_fixture()
    #assert {:error, %Ecto.Changeset{}} = AppEngine.API.Device.update_device_status(device_status, @invalid_attrs)
    #assert device_status == AppEngine.API.Device.get_device_status!(device_status.id)
  end

  test "change_device_status/1 returns a device_status changeset" do
    #device_status = device_status_fixture()
    #assert %Ecto.Changeset{} = AppEngine.API.Device.change_device_status(device_status)
  end
end
