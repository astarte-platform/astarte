#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.V2GroupTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Plug.Conn
  import Phoenix.ConnTest
  import Astarte.AppEngine.APIWeb.Router.Helpers

  # The default endpoint for testing
  @endpoint Astarte.AppEngine.APIWeb.Endpoint

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.Test.Generators.Group, as: GroupGenerator
  alias Astarte.Test.Generators.Device, as: DeviceGenerator

  describe "create" do
    @tag :unit
    @tag :v2
    @tag :group
    @tag interface_count: 10
    @tag device_count: 100
    @tag group_count: 2
    setup [
      {DatabaseSetup, :connect},
      {DatabaseSetup, :keyspace},
      {DatabaseSetup, :setup},
      {DatabaseSetup, :setup_auth},
      {ConnSetup, :create_conn},
      {ConnSetup, :jwt},
      {ConnSetup, :auth_conn}
    ]

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

    @tag :unit
    @tag :v2
    @tag :group
    @tag interface_count: 10
    @tag device_count: 100
    @tag group_count: 2
    setup [
      {DatabaseSetup, :connect},
      {DatabaseSetup, :keyspace},
      {DatabaseSetup, :setup},
      {DatabaseSetup, :setup_auth},
      {ConnSetup, :create_conn},
      {ConnSetup, :jwt},
      {ConnSetup, :auth_conn}
    ]

    property "fails when devices list empty", %{auth_conn: auth_conn, keyspace: keyspace} do
      @tag :unit
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

    @tag :unit
    @tag :v2
    @tag :group
    @tag interface_count: 10
    @tag device_count: 100
    @tag group_count: 2
    setup [
      {DatabaseSetup, :connect},
      {DatabaseSetup, :keyspace},
      {DatabaseSetup, :setup},
      {DatabaseSetup, :setup_auth},
      {ConnSetup, :create_conn},
      {ConnSetup, :jwt},
      {ConnSetup, :auth_conn}
    ]

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

    @tag :unit
    @tag :v2
    @tag :group
    @tag interface_count: 10
    @tag device_count: 100
    @tag group_count: 2
    setup [
      {DatabaseSetup, :connect},
      {DatabaseSetup, :keyspace},
      {DatabaseSetup, :setup},
      {DatabaseSetup, :setup_auth},
      {InterfaceSetup, :init},
      {InterfaceSetup, :setup},
      {DeviceSetup, :init},
      {DeviceSetup, :setup},
      {GroupSetup, :init},
      {GroupSetup, :setup},
      {ConnSetup, :create_conn},
      {ConnSetup, :jwt},
      {ConnSetup, :auth_conn}
    ]

    test "fails when the group already exists", %{
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

    setup [
      {DatabaseSetup, :connect},
      {DatabaseSetup, :keyspace},
      {DatabaseSetup, :setup},
      {DatabaseSetup, :setup_auth},
      {InterfaceSetup, :init},
      {InterfaceSetup, :setup},
      {DeviceSetup, :init},
      {DeviceSetup, :setup},
      {GroupSetup, :init},
      {GroupSetup, :setup},
      {ConnSetup, :create_conn},
      {ConnSetup, :jwt},
      {ConnSetup, :auth_conn}
    ]

    @tag :unit
    @tag :v2
    @tag :group
    @tag interface_count: 10
    @tag device_count: 100
    @tag group_count: 2
    test "success creates groups with valid parameters", %{
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
