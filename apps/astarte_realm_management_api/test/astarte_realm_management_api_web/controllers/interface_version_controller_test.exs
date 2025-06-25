#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.APIWeb.InterfaceVersionControllerTest do
  use Astarte.RealmManagement.API.DataCase, async: true
  use Astarte.RealmManagement.APIWeb.ConnCase

  alias Astarte.RealmManagement.Queries
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB
  alias Astarte.Core.Generators

  import ExUnit.CaptureLog

  describe "index" do
    test "lists empty interface versions", %{auth_conn: conn, realm: realm} do
      interface = Generators.Interface.interface() |> Enum.at(0)
      conn = get(conn, interface_version_path(conn, :index, realm, interface.name))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists interface after installing it", %{auth_conn: conn, realm: realm} do
      interface = Generators.Interface.interface() |> Enum.at(0)
      _ = install_interface(conn, realm, interface)

      list_conn = get(conn, interface_version_path(conn, :index, realm, interface.interface_name))
      assert json_response(list_conn, 200)["data"] == [interface.version_major]

      # Cleanup
      capture_log(fn ->
        Queries.delete_interface(realm, interface.name, interface.major_version)
      end)
    end

    test "lists multiple major versions", %{auth_conn: conn, realm: realm} do
      major = StreamData.integer(0..8) |> Enum.at(0)

      interface =
        Generators.Interface.interface(major_version: major) |> Enum.at(0)

      post_conn_1 = install_interface(conn, realm, interface)

      next_interface = Map.update!(interface, :major_version, &(&1 + 1))

      post_conn_2 = install_interface(post_conn_1, realm, next_interface)

      list_conn =
        get(conn, interface_version_path(post_conn_2, :index, realm, interface.interface_name))

      assert json_response(list_conn, 200)["data"] == [major, major + 1]

      # Cleanup
      capture_log(fn ->
        Queries.delete_interface(realm, interface.name, interface.major_version)

        Queries.delete_interface(
          realm,
          next_interface.name,
          next_interface.major_version
        )
      end)
    end
  end

  defp install_interface(conn, realm, interface) do
    interface_data = interface |> to_input_map()
    post_conn = post(conn, interface_path(conn, :create, realm), data: interface_data)
    assert response(post_conn, 201) == ""

    # TODO: remove when all interface functions are migrated to
    # Astarte.RealmManagement.API
    DB.install_interface(realm, interface)

    post_conn
  end
end
