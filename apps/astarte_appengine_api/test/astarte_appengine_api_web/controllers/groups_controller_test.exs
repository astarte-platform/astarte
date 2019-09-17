#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.GroupsControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.DatabaseTestHelper
  alias Astarte.AppEngine.API.JWTTestHelper
  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Groups

  @realm "autotestrealm"
  @group_name "mygroup"
  @group_devices [
    "f0VMRgIBAQAAAAAAAAAAAA",
    "olFkumNuZ_J0f_d6-8XCDg"
  ]
  @device_id_in_group "olFkumNuZ_J0f_d6-8XCDg"

  setup_all do
    {:ok, _client} = DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    :ok
  end

  setup %{conn: conn} do
    DatabaseTestHelper.seed_data()

    authorized_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "bearer #{JWTTestHelper.gen_jwt_all_access_token()}")

    {:ok, conn: authorized_conn}
  end

  describe "index" do
    test "returns 403 on unexisting realm", %{conn: conn} do
      conn = get(conn, groups_path(conn, :index, "unexisting"))

      assert json_response(conn, 403)["errors"] == %{"detail" => "Forbidden"}
    end

    test "returns an empty list on empty realm", %{conn: conn} do
      conn = get(conn, groups_path(conn, :index, @realm))

      assert json_response(conn, 200)["data"] == []
    end

    test "returns the groups on a populated realm", %{conn: conn} do
      params = %{
        "group_name" => @group_name,
        "devices" => @group_devices
      }

      create_conn = post(conn, groups_path(conn, :create, @realm), data: params)

      assert json_response(create_conn, 201)["data"] == params

      list_conn = get(conn, groups_path(conn, :index, @realm))

      assert json_response(list_conn, 200)["data"] == [@group_name]
    end
  end

  describe "create" do
    test "rejects invalid group name", %{conn: conn} do
      params = %{
        "group_name" => "astarte_reserved_group",
        "devices" => @group_devices
      }

      conn = post(conn, groups_path(conn, :create, @realm), data: params)

      assert json_response(conn, 422)["errors"]["group_name"] != nil
    end

    test "rejects group names with astarte prefix", %{conn: conn} do
      params = %{
        "group_name" => "astarte-group",
        "devices" => @group_devices
      }

      conn = post(conn, groups_path(conn, :create, @realm), data: params)

      assert json_response(conn, 422)["errors"]["group_name"] != nil
    end

    test "rejects empty devices", %{conn: conn} do
      params = %{
        "group_name" => @group_name,
        "devices" => []
      }

      conn = post(conn, groups_path(conn, :create, @realm), data: params)

      assert json_response(conn, 422)["errors"]["devices"] != nil
    end

    test "doesn't create group if a device doesn't exist", %{conn: conn} do
      params = %{
        "group_name" => @group_name,
        "devices" => [
          "2uL21mYBQsWVik8declWQQ"
          | @group_devices
        ]
      }

      create_conn = post(conn, groups_path(conn, :create, @realm), data: params)

      assert json_response(create_conn, 422)["errors"]["devices"] != nil

      show_conn = get(conn, groups_path(conn, :show, @realm, @group_name))

      assert json_response(show_conn, 404)
    end

    test "creates the group with valid parameters", %{conn: conn} do
      params = %{
        "group_name" => @group_name,
        "devices" => @group_devices
      }

      create_conn = post(conn, groups_path(conn, :create, @realm), data: params)

      assert json_response(create_conn, 201)["data"] == params

      show_conn = get(conn, groups_path(conn, :show, @realm, @group_name))

      assert json_response(show_conn, 200)["data"]["group_name"] == @group_name

      for device <- @group_devices do
        {:ok, %DeviceStatus{groups: groups}} = Device.get_device_status!(@realm, device)
        assert groups == [@group_name]
      end
    end

    test "rejects an already existing group", %{conn: conn} do
      params = %{
        "group_name" => @group_name,
        "devices" => @group_devices
      }

      create_conn = post(conn, groups_path(conn, :create, @realm), data: params)

      assert json_response(create_conn, 201)["data"] == params

      create_again_conn = post(conn, groups_path(conn, :create, @realm), data: params)

      assert json_response(create_again_conn, 409)["errors"] != nil
    end

    test "creates the group with / in group name", %{conn: conn} do
      group_name = "world/europe/italy"
      encoded_group_name = "world%2Feurope%2Fitaly"

      params = %{
        "group_name" => group_name,
        "devices" => @group_devices
      }

      create_conn = post(conn, groups_path(conn, :create, @realm), data: params)

      assert json_response(create_conn, 201)["data"] == params

      show_conn = get(conn, groups_path(conn, :show, @realm, encoded_group_name))

      assert json_response(show_conn, 200)["data"]["group_name"] == group_name
    end
  end

  describe "show" do
    test "returns 404 for non-existing group", %{conn: conn} do
      conn = get(conn, groups_path(conn, :show, @realm, "nonexisting"))

      assert json_response(conn, 404)["errors"]["detail"] == "Group not found"
    end
  end

  describe "devices index" do
    test "returns 404 for non-existing group", %{conn: conn} do
      conn = get(conn, groups_path(conn, :devices_index, @realm, "nonexisting"))

      assert json_response(conn, 404)["errors"]["detail"] == "Group not found"
    end

    test "returns the devices for a populated group", %{conn: conn} do
      params = %{
        "group_name" => @group_name,
        "devices" => @group_devices
      }

      create_conn = post(conn, groups_path(conn, :create, @realm), data: params)

      assert json_response(create_conn, 201)["data"] == params

      devices_index_conn = get(conn, groups_path(conn, :devices_index, @realm, @group_name))

      assert devices = json_response(devices_index_conn, 200)["data"]

      for device <- @group_devices do
        assert Enum.member?(devices, device)
      end
    end
  end

  describe "add device" do
    setup [:create_group]

    test "returns 404 for non-existing group", %{conn: conn} do
      params = %{
        "device_id" => "aWag-VlVKC--1S-vfzZ9uQ"
      }

      conn = post(conn, groups_path(conn, :add_device, @realm, "nonexisting"), data: params)

      assert json_response(conn, 404)["errors"]["detail"] == "Group not found"
    end

    test "fails with non-existing device", %{conn: conn} do
      params = %{
        "device_id" => "X-Qv0zPMRfiWEXUMHZFNVw"
      }

      conn = post(conn, groups_path(conn, :add_device, @realm, @group_name), data: params)

      assert json_response(conn, 422)["errors"]["device_id"] != nil
    end

    test "returns 409 for duplicate device", %{conn: conn} do
      params = %{
        "device_id" => "f0VMRgIBAQAAAAAAAAAAAA"
      }

      conn = post(conn, groups_path(conn, :add_device, @realm, @group_name), data: params)

      assert json_response(conn, 409)["errors"]["detail"] == "Device already in group"
    end

    test "succeeds with valid params", %{conn: conn} do
      device_id = "aWag-VlVKC--1S-vfzZ9uQ"

      params = %{
        "device_id" => device_id
      }

      create_conn = post(conn, groups_path(conn, :add_device, @realm, @group_name), data: params)

      assert response(create_conn, 201)

      devices_index_conn = get(conn, groups_path(conn, :devices_index, @realm, @group_name))

      assert Enum.member?(json_response(devices_index_conn, 200)["data"], device_id)

      {:ok, %DeviceStatus{groups: groups}} = Device.get_device_status!(@realm, device_id)
      assert groups == [@group_name]
    end
  end

  describe "delete device" do
    setup [:create_group]

    test "returns 404 for non-existing group", %{conn: conn} do
      conn =
        delete(
          conn,
          groups_path(conn, :remove_device, @realm, "nonexisting", @device_id_in_group)
        )

      assert json_response(conn, 404)["errors"]["detail"] == "Group not found"
    end

    test "returns 404 for non-existing device", %{conn: conn} do
      conn =
        delete(
          conn,
          groups_path(conn, :remove_device, @realm, @group_name, "agtp2h0srgcaqcsqnnkmnw")
        )

      assert json_response(conn, 404)["errors"]["detail"] == "Device not found"
    end

    test "succesfully delete device", %{conn: conn} do
      delete_conn =
        delete(
          conn,
          groups_path(conn, :remove_device, @realm, @group_name, @device_id_in_group)
        )

      assert response(delete_conn, 204)

      devices_index_conn = get(conn, groups_path(conn, :devices_index, @realm, @group_name))

      assert not Enum.member?(json_response(devices_index_conn, 200)["data"], @device_id_in_group)

      {:ok, %DeviceStatus{groups: groups}} =
        Device.get_device_status!(@realm, @device_id_in_group)

      assert not Enum.member?(groups, @group_name)
    end

    test "deletes group if all devices are deleted", %{conn: conn} do
      for device <- @group_devices do
        delete_conn =
          delete(
            conn,
            groups_path(conn, :remove_device, @realm, @group_name, device)
          )

        assert response(delete_conn, 204)
      end

      show_conn = get(conn, groups_path(conn, :show, @realm, @group_name))

      assert json_response(show_conn, 404)["errors"]["detail"] == "Group not found"
    end
  end

  defp create_group(_context) do
    params = %{
      "group_name" => @group_name,
      "devices" => @group_devices
    }

    {:ok, _} = Groups.create_group(@realm, params)
    :ok
  end
end
