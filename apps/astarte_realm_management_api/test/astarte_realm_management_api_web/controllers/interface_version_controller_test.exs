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

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerators
  alias Astarte.Helpers.Database
  alias Astarte.RealmManagement.API.Interfaces
  alias Astarte.RealmManagement.API.Interfaces.Core

  import ExUnit.CaptureLog

  describe "index" do
    setup %{realm_name: realm_name, astarte_instance_id: astarte_instance_id} do
      interface = InterfaceGenerators.interface() |> Enum.at(0)
      interface_params = interface |> to_input_map()

      {:ok, installed_interface} = Interfaces.install_interface(realm_name, interface_params)

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)

        capture_log(fn ->
          Core.delete_interface(realm_name, interface.name, interface.major_version)
        end)
      end)

      %{interface: installed_interface}
    end

    test "returns 404 when requesting versions for a non-existent interface", %{
      auth_conn: auth_conn,
      realm: realm
    } do
      conn =
        get(auth_conn, interface_version_path(auth_conn, :index, realm, "com.Some.Interface"))

      assert json_response(conn, 404)["errors"]["detail"] == "Interface not found"
    end

    test "returns the major version after installing a single interface", %{
      auth_conn: auth_conn,
      realm_name: realm_name,
      interface: interface
    } do
      list_conn =
        get(auth_conn, interface_version_path(auth_conn, :index, realm_name, interface.name))

      assert json_response(list_conn, 200)["data"] == [interface.major_version]
    end

    test "returns all major versions after installing multiple versions of the same interface", %{
      auth_conn: auth_conn,
      realm_name: realm_name,
      interface: interface
    } do
      interface2 = %{interface | :major_version => interface.major_version + 1}
      interface_params = interface2 |> to_input_map()

      {:ok, interface2} = Interfaces.install_interface(realm_name, interface_params)

      list_conn =
        get(auth_conn, interface_version_path(auth_conn, :index, realm_name, interface.name))

      assert json_response(list_conn, 200)["data"] == [
               interface.major_version,
               interface2.major_version
             ]

      # Cleanup
      capture_log(fn ->
        Core.delete_interface(realm_name, interface2.name, interface2.major_version)
      end)
    end
  end
end
