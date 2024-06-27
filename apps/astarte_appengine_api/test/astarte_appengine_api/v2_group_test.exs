defmodule Astarte.AppEngine.API.V2GroupTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  use Astarte.Test.Cases.Group
  use Astarte.Test.Cases.Conn

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.Test.Setups.Database, as: DatabaseSetup
  alias Astarte.Test.Setups.Conn, as: ConnSetup
  alias Astarte.Test.Generators.Group, as: GroupGenerator
  alias Astarte.Test.Generators.Device, as: DeviceGenerator

  @moduletag :v2
  @moduletag :group
  @moduletag interface_count: 10
  @moduletag device_count: 100
  @moduletag group_count: 2

  describe "create" do
    property "fails when group name is not valid", %{auth_conn: auth_conn, keyspace: keyspace} do
      check all {{group_name, error}, devices} <-
                  tuple({
                    bind(GroupGenerator.name(), fn name ->
                      bind(integer(0..2), fn num ->
                        constant(
                          case num do
                            0 -> {"", "can't be blank"}
                            1 -> {"~" <> name, "is not valid"}
                            2 -> {"@" <> name, "is not valid"}
                          end
                        )
                      end)
                    end),
                    list_of(DeviceGenerator.encoded_id(), min_length: 0, max_length: 1)
                  }) do
        params = %{
          "group_name" => group_name,
          "devices" => devices
        }

        response = post(auth_conn, groups_path(auth_conn, :create, keyspace), data: params)
        assert [error] === json_response(response, 422)["errors"]["group_name"]
      end
    end

    property "fails when devices list empty", %{auth_conn: auth_conn, keyspace: keyspace} do
      check all group_name <- GroupGenerator.name() do
        params = %{
          "group_name" => group_name,
          "devices" => []
        }

        response = post(auth_conn, groups_path(auth_conn, :create, keyspace), data: params)

        assert ["should have at least 1 item(s)"] ===
                 json_response(response, 422)["errors"]["devices"]
      end
    end

    property "fails when device does not exist", %{auth_conn: auth_conn, keyspace: keyspace} do
      check all group_name <- GroupGenerator.name(),
                devices <- list_of(DeviceGenerator.encoded_id(), min_length: 1) do
        params = %{
          "group_name" => group_name,
          "devices" => devices
        }

        response = post(auth_conn, groups_path(auth_conn, :create, keyspace), data: params)

        assert ["must exist (#{Enum.at(devices, 0)} not found)"] ===
                 json_response(response, 422)["errors"]["devices"]
      end
    end

    property "fails when the group already exists", %{
      auth_conn: auth_conn,
      cluster: cluster,
      keyspace: keyspace,
      interfaces: interfaces,
      devices: devices,
      groups: groups
    } do
      device_ids = Enum.map(devices, & &1.encoded_id)
      existing_group_name = Enum.at(groups, 0).name

      params = %{
        "group_name" => existing_group_name,
        "devices" => device_ids
      }

      response = post(auth_conn, groups_path(auth_conn, :create, keyspace), data: params)
      assert "Group already exists" === json_response(response, 409)["errors"]["detail"]
    end

    property "success creates groups with valid parameters", %{
      auth_conn: auth_conn,
      cluster: cluster,
      keyspace: keyspace,
      interfaces: interfaces,
      devices: devices,
      groups: groups
    } do
      device_ids = Enum.map(devices, & &1.encoded_id)
      old_group_names = Enum.map(groups, & &1.name)

      check all group_name <-
                  filter(GroupGenerator.name(), fn name -> name not in old_group_names end) do
        params = %{
          "group_name" => group_name,
          "devices" => device_ids
        }

        response = post(auth_conn, groups_path(auth_conn, :create, keyspace), data: params)
        assert params === json_response(response, 201)["data"]
        response = get(auth_conn, groups_path(auth_conn, :show, keyspace, group_name))
        assert group_name === json_response(response, 200)["data"]["group_name"]

        for device <- device_ids do
          {:ok, %DeviceStatus{groups: groups}} = Device.get_device_status!(keyspace, device)
          assert group_name in groups
          # TODO right way
          # assert [group_name] === groups -- old_group_names
        end
      end
    end
  end
end
