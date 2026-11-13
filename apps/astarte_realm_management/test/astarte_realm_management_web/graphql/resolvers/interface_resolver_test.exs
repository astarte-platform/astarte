#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.RealmManagementWeb.GraphQL.Resolvers.InterfaceResolverTest do
  use Astarte.RealmManagement.Cases.Data, async: true
  use Mimic

  alias Astarte.RealmManagement.Helpers.Database
  alias Astarte.RealmManagement.Interfaces
  alias Astarte.RealmManagement.Interfaces.Core
  alias Astarte.RealmManagementWeb.GraphQL.Resolvers.InterfaceResolver

  @interface_name "com.Some.Interface"
  @interface_major 0
  @valid_attrs %{
    "interface_name" => @interface_name,
    "version_major" => @interface_major,
    "version_minor" => 2,
    "type" => "properties",
    "ownership" => "device",
    "mappings" => [
      %{
        "endpoint" => "/test",
        "type" => "integer"
      }
    ]
  }

  setup %{realm_name: realm_name, astarte_instance_id: astarte_instance_id} do
    resolution = %{
      context: %{
        realm_name: realm_name
      }
    }

    on_exit(fn ->
      Database.setup_database_access(astarte_instance_id)
      # Cleanup after tests
      try do
        Core.delete_interface(realm_name, @interface_name, @interface_major)
      rescue
        _ -> :ok
      end
    end)

    %{resolution: resolution, valid_attrs: @valid_attrs}
  end

  describe "install_interface/3" do
    test "installs an interface successfully", %{resolution: resolution, valid_attrs: valid_attrs} do
      args = %{data: Map.put(valid_attrs, "interface_name", "com.New.Interface")}

      assert {:ok, "Interface installed successfully"} =
               InterfaceResolver.install_interface(nil, args, resolution)
    end
  end

  describe "get_interface/3" do
    setup %{realm_name: realm_name, valid_attrs: valid_attrs} do
      Interfaces.install_interface(realm_name, valid_attrs, async: false)
      :ok
    end

    test "returns an interface successfully", %{resolution: resolution} do
      args = %{interface_name: @interface_name, major_version: @interface_major}

      assert {:ok, %Astarte.Core.Interface{name: @interface_name}} =
               InterfaceResolver.get_interface(nil, args, resolution)
    end

    test "returns error if not found", %{resolution: resolution} do
      args = %{interface_name: "com.Invalid.Interface", major_version: 1}

      assert {:error, "Interface not found"} =
               InterfaceResolver.get_interface(nil, args, resolution)
    end
  end

  describe "get_interface_versions/3" do
    setup %{realm_name: realm_name, valid_attrs: valid_attrs} do
      Interfaces.install_interface(realm_name, valid_attrs, async: false)
      :ok
    end

    test "returns versions successfully", %{resolution: resolution} do
      args = %{interface_name: @interface_name}

      assert {:ok, [@interface_major]} =
               InterfaceResolver.get_interface_versions(nil, args, resolution)
    end

    test "returns error if not found", %{resolution: resolution} do
      args = %{interface_name: "com.Invalid.Interface"}

      assert {:error, "Interface not found"} =
               InterfaceResolver.get_interface_versions(nil, args, resolution)
    end
  end

  describe "list_interfaces/3" do
    setup %{realm_name: realm_name, valid_attrs: valid_attrs} do
      Interfaces.install_interface(realm_name, valid_attrs, async: false)
      :ok
    end

    test "lists interfaces successfully", %{resolution: resolution} do
      assert {:ok, names} = InterfaceResolver.list_interfaces(nil, %{}, resolution)
      assert Enum.member?(names, @interface_name)
    end
  end

  describe "update_interface/3" do
    setup %{realm_name: realm_name, valid_attrs: valid_attrs} do
      Interfaces.install_interface(realm_name, valid_attrs, async: false)
      :ok
    end

    test "updates an interface successfully", %{resolution: resolution, valid_attrs: valid_attrs} do
      updated_attrs = Map.put(valid_attrs, "version_minor", 3)

      args = %{
        interface_name: @interface_name,
        major_version: @interface_major,
        data: updated_attrs
      }

      assert {:ok, "Interface updated successfully"} =
               InterfaceResolver.update_interface(nil, args, resolution)
    end
  end

  describe "delete_interface_draft/3" do
    setup %{realm_name: realm_name, valid_attrs: valid_attrs} do
      Interfaces.install_interface(realm_name, valid_attrs, async: false)
      :ok
    end

    test "deletes an interface successfully", %{resolution: resolution} do
      args = %{interface_name: @interface_name, major_version: @interface_major}

      assert {:ok, "Interface draft deleted successfully"} =
               InterfaceResolver.delete_interface_draft(nil, args, resolution)
    end
  end

  describe "missing context" do
    test "returns error when realm_name is missing" do
      resolution = %{context: %{}}

      assert {:error, "Missing realm context"} =
               InterfaceResolver.list_interfaces(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               InterfaceResolver.get_interface(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               InterfaceResolver.get_interface_versions(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               InterfaceResolver.install_interface(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               InterfaceResolver.update_interface(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               InterfaceResolver.delete_interface_draft(nil, %{}, resolution)
    end
  end
end
