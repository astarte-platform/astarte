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

defmodule Astarte.RealmManagement.API.InterfacesTest do
  use Astarte.RealmManagement.API.DataCase, async: true
  use ExUnitProperties

  @moduletag :interfaces
  # TODO: This module is only being kept for reference. Remove it altogether
  # when the interfaces functions have been migrated to the API service.
  @moduletag :skip

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping
  alias Astarte.Helpers.Database
  alias Astarte.RealmManagement.API.Interfaces
  alias Astarte.RealmManagement.Engine
  alias Astarte.RealmManagement.Queries
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB

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
  @invalid_attrs %{
    "interface_name" => @interface_name,
    "version_major" => 2,
    "version_minor" => 1,
    "type" => "INVALID",
    "ownership" => "device",
    "mappings" => [
      %{
        "endpoint" => "/test",
        "type" => "integer"
      }
    ]
  }

  describe "interface creation" do
    @describetag :creation

    test "succeeds with valid attrs", %{realm: realm} do
      assert {:ok, %Interface{} = interface} = Interfaces.create_interface(realm, @valid_attrs)

      assert %Interface{
               name: @interface_name,
               major_version: @interface_major,
               minor_version: 2,
               type: :properties,
               ownership: :device,
               mappings: [mapping]
             } = interface

      assert %Mapping{
               endpoint: "/test",
               value_type: :integer
             } = mapping

      assert {:ok, [@interface_name]} = Interfaces.list_interfaces(realm)
    end

    test "fails with already installed interface", %{realm: realm} do
      assert {:ok, %Interface{} = _interface} = Interfaces.create_interface(realm, @valid_attrs)

      assert {:error, :already_installed_interface} =
               Interfaces.create_interface(realm, @valid_attrs)
    end

    test "fails when interface name collides after normalization", %{realm: realm} do
      normalized_attrs =
        @valid_attrs
        |> Map.put("interface_name", "com.astarteplatform.Interface")

      {:ok, %Interface{}} = Interfaces.create_interface(realm, normalized_attrs)

      colliding_normalized_attrs =
        @valid_attrs
        |> Map.put("interface_name", "com.astarte-platform.Interface")

      assert {:error, :interface_name_collision} =
               Interfaces.create_interface(realm, colliding_normalized_attrs)
    end

    test "fails with invalid attrs", %{realm: realm} do
      assert {:error, %Ecto.Changeset{errors: [type: _]}} =
               Interfaces.create_interface(realm, @invalid_attrs)
    end

    test "succeeds using a synchronous call", %{realm: realm} do
      assert {:ok, %Interface{} = interface} =
               Interfaces.create_interface(realm, @valid_attrs, async_operation: false)

      assert %Interface{
               name: @interface_name,
               major_version: @interface_major,
               minor_version: 2,
               type: :properties,
               ownership: :device,
               mappings: [mapping]
             } = interface

      assert %Mapping{
               endpoint: "/test",
               value_type: :integer
             } = mapping

      assert {:ok, [@interface_name]} = Interfaces.list_interfaces(realm)
    end

    test "fails when a mapping higher database_retention_ttl than the maximum", %{realm: realm} do
      alias Astarte.RealmManagement.API.Helpers.RPCMock.DB
      DB.put_datastream_maximum_storage_retention(realm, 1)

      iface_with_invalid_mappings = %{
        @valid_attrs
        | "mappings" => [
            %{
              "endpoint" => "/test",
              "type" => "integer",
              "database_retention_policy" => "use_ttl",
              "database_retention_ttl" => 60
            }
          ],
          "type" => "datastream"
      }

      assert {:error, :maximum_database_retention_exceeded} =
               Interfaces.create_interface(realm, iface_with_invalid_mappings)
    end
  end

  describe "interface update" do
    @describetag :update

    setup %{realm: realm, astarte_instance_id: astarte_instance_id} do
      {:ok, interface} = create_interface(realm, @valid_attrs)

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)

        # Use queries to avoid checks on the major version
        Queries.delete_interface(realm, interface.name, interface.major_version)
      end)

      :ok
    end

    test "succeeds with valid attrs", %{realm: realm} do
      doc = "some doc"

      update_attrs =
        @valid_attrs
        |> Map.put("version_minor", 10)
        |> Map.put("doc", doc)

      assert :ok ==
               Interfaces.update_interface(
                 realm,
                 @interface_name,
                 @interface_major,
                 update_attrs
               )

      # TODO: remove after get_interface is removed
      update_interface(realm, @interface_name, @interface_major)

      assert {:ok, interface_source} =
               Interfaces.fetch_interface(realm, @interface_name, @interface_major)

      assert {:ok, map} = Jason.decode(interface_source)

      assert {:ok, interface} =
               Interface.changeset(%Interface{}, map) |> Ecto.Changeset.apply_action(:insert)

      assert %Interface{
               name: "com.Some.Interface",
               major_version: @interface_major,
               minor_version: 10,
               type: :properties,
               ownership: :device,
               mappings: [mapping],
               doc: ^doc
             } = interface

      assert %Mapping{
               endpoint: "/test",
               value_type: :integer
             } = mapping

      assert {:ok, ["com.Some.Interface"]} = Interfaces.list_interfaces(realm)
    end

    test "fails with not installed interface", %{realm: realm} do
      update_attrs =
        @valid_attrs
        |> Map.put("interface_name", "com.NotExisting")

      assert {:error, :interface_major_version_does_not_exist} =
               Interfaces.update_interface(
                 realm,
                 "com.NotExisting",
                 @interface_major,
                 update_attrs
               )
    end

    test "fails when minor version is not increased", %{realm: realm} do
      doc = "some doc"

      update_attrs =
        @valid_attrs
        |> Map.put("doc", doc)

      assert {:error, :minor_version_not_increased} ==
               Interfaces.update_interface(
                 realm,
                 @interface_name,
                 @interface_major,
                 update_attrs
               )
    end

    test "fails when minor version is decreased", %{realm: realm} do
      doc = "some doc"

      update_attrs =
        @valid_attrs
        |> Map.put("version_minor", 1)
        |> Map.put("doc", doc)

      assert {:error, :downgrade_not_allowed} ==
               Interfaces.update_interface(
                 realm,
                 @interface_name,
                 @interface_major,
                 update_attrs
               )
    end

    test "fails with missing endpoints", %{realm: realm} do
      update_attrs =
        @valid_attrs
        |> Map.put("version_minor", 10)
        |> Map.put("mappings", [
          %{
            "endpoint" => "/new_endpoint",
            "type" => "integer"
          }
        ])

      assert {:error, :missing_endpoints} ==
               Interfaces.update_interface(
                 realm,
                 @interface_name,
                 @interface_major,
                 update_attrs
               )
    end

    test "fails with incompatible endpoint change", %{realm: realm} do
      update_attrs =
        @valid_attrs
        |> Map.put("version_minor", 10)
        |> Map.put("mappings", [
          %{
            "endpoint" => "/test",
            # Changing the type from integer to string
            "type" => "string"
          }
        ])

      assert {:error, :incompatible_endpoint_change} ==
               Interfaces.update_interface(
                 realm,
                 @interface_name,
                 @interface_major,
                 update_attrs
               )
    end

    test "fails with invalid attrs", %{realm: realm} do
      assert {:error, %Ecto.Changeset{errors: [type: _]}} =
               Interfaces.create_interface(realm, @invalid_attrs)
    end

    test "succeeds with valid attrs using a synchronous call", %{realm: realm} do
      doc = "some doc"

      update_attrs =
        @valid_attrs
        |> Map.put("version_minor", 10)
        |> Map.put("doc", doc)

      assert :ok ==
               Interfaces.update_interface(
                 realm,
                 @interface_name,
                 @interface_major,
                 update_attrs,
                 async_operation: false
               )

      # TODO: remove after `get_interface_source` rpc is removed
      update_interface(realm, @interface_name, @interface_major)

      assert {:ok, interface_source} =
               Interfaces.fetch_interface(realm, @interface_name, @interface_major)

      assert {:ok, map} = Jason.decode(interface_source)

      assert {:ok, interface} =
               Interface.changeset(%Interface{}, map) |> Ecto.Changeset.apply_action(:insert)

      assert %Interface{
               name: "com.Some.Interface",
               major_version: @interface_major,
               minor_version: 10,
               type: :properties,
               ownership: :device,
               mappings: [mapping],
               doc: ^doc
             } = interface

      assert %Mapping{
               endpoint: "/test",
               value_type: :integer
             } = mapping

      assert {:ok, ["com.Some.Interface"]} = Interfaces.list_interfaces(realm)
    end
  end

  describe "updating interfaces" do
    @describetag :update

    property "works with valid update", %{realm: realm} do
      check all interface <-
                  Astarte.Core.Generators.Interface.interface(minor_version: integer(1..254)),
                valid_update_interface <-
                  Astarte.Core.Generators.Interface.interface(
                    name: interface.name,
                    major_version: interface.major_version,
                    minor_version: integer((interface.minor_version + 1)..255),
                    type: interface.type,
                    ownership: interface.ownership,
                    aggregation: interface.aggregation,
                    interface_id: interface.interface_id,
                    mappings: interface.mappings
                  ) do
        json_interface = Jason.encode!(interface)

        updated_interface_params =
          valid_update_interface |> Jason.encode!() |> Jason.decode!(keys: :atoms)

        # TODO: change after removal of `install_interface` rpc
        :ok = Engine.install_interface(realm, json_interface)

        assert :ok =
                 Interfaces.update_interface(
                   realm,
                   interface.name,
                   interface.major_version,
                   updated_interface_params
                 )

        # TODO: change after removal of `get_interface_source` rpc
        {:ok, interface_json} =
          Engine.interface_source(realm, interface.name, interface.major_version)

        interface_params =
          Jason.decode!(interface_json, keys: :atoms)

        interface =
          Interface.changeset(%Interface{}, interface_params)
          |> Ecto.Changeset.apply_action!(:insert)

        %{
          name: name,
          major_version: major,
          minor_version: minor
        } = interface

        assert %Astarte.Core.Interface{
                 name: ^name,
                 major_version: ^major,
                 minor_version: ^minor
               } = valid_update_interface

        # TODO: change after removal of `delete_interface` rpc
        # Use queries to avoid checks on the major version
        Queries.delete_interface(realm, interface.name, interface.major_version)
      end
    end

    property "does not allow major version changes", %{realm: realm} do
      check all(
              interface <-
                Astarte.Core.Generators.Interface.interface(major_version: integer(0..8)),
              updated_interface <-
                Astarte.Core.Generators.Interface.interface(
                  name: interface.name,
                  major_version: interface.major_version + 1
                )
            ) do
        json_interface = Jason.encode!(interface)

        interface_update =
          updated_interface |> Jason.encode!() |> Jason.decode!(keys: :atoms)

        _ = Engine.install_interface(realm, json_interface)

        assert {:error, :major_version_not_matching} =
                 Interfaces.update_interface(
                   realm,
                   interface.name,
                   interface.major_version,
                   interface_update
                 )

        # TODO: change after removal of `delete_interface` rpc
        # Use queries to avoid checks on the major version
        Queries.delete_interface(realm, interface.name, interface.major_version)
      end
    end

    property "does not allow downgrade", %{realm: realm} do
      check all(
              interface <-
                Astarte.Core.Generators.Interface.interface(minor_version: integer(2..255)),
              updated_interface <-
                Astarte.Core.Generators.Interface.interface(
                  name: interface.name,
                  major_version: interface.major_version,
                  minor_version: interface.minor_version - 1,
                  type: interface.type,
                  ownership: interface.ownership,
                  aggregation: interface.aggregation,
                  interface_id: interface.interface_id,
                  mappings: interface.mappings
                )
            ) do
        json_interface = Jason.encode!(interface)

        interface_update =
          updated_interface |> Jason.encode!() |> Jason.decode!(keys: :atoms)

        _ = Engine.install_interface(realm, json_interface)

        {:error, :downgrade_not_allowed} =
          Interfaces.update_interface(
            realm,
            interface.name,
            interface.major_version,
            interface_update
          )

        # TODO: change after removal of `delete_interface` rpc
        # Use queries to avoid checks on the major version
        Queries.delete_interface(realm, interface.name, interface.major_version)
      end
    end
  end

  describe "interface deletion" do
    @describetag :deletion

    setup %{realm: realm} do
      {:ok, %Interface{}} = Interfaces.create_interface(realm, @valid_attrs)
      :ok
    end

    test "succeeds with valid interface", %{realm: realm} do
      assert :ok = Interfaces.delete_interface(realm, @interface_name, @interface_major)

      assert {:error, :interface_not_found} =
               Interfaces.fetch_interface(realm, @interface_name, @interface_major)
    end

    test "fails if major version is other than 0", %{realm: realm} do
      new_interface_major = 1

      major_attrs =
        @valid_attrs
        |> Map.put("version_major", new_interface_major)

      assert {:ok, %Interface{}} = Interfaces.create_interface(realm, major_attrs)

      assert {:error, :forbidden} =
               Interfaces.delete_interface(realm, @interface_name, new_interface_major)
    end

    test "fails with not installed interface", %{realm: realm} do
      assert {:error, :interface_not_found} =
               Interfaces.delete_interface(realm, "com.NotExisting", @interface_major)
    end

    test "returns error for invalid realm" do
      assert {:error, :interface_not_found} =
               Interfaces.delete_interface("invalidrealm", @interface_name, @interface_major)
    end

    test "succeeds using a synchronous call", %{realm: realm} do
      assert :ok =
               Interfaces.delete_interface(
                 realm,
                 @interface_name,
                 @interface_major,
                 async_operation: false
               )

      assert {:error, :interface_not_found} =
               Interfaces.fetch_interface(realm, @interface_name, @interface_major)
    end
  end

  defp create_interface(realm_name, params) do
    with {:ok, interface} <- Interfaces.create_interface(realm_name, params) do
      interface_json = Jason.encode!(interface)
      Engine.install_interface(realm_name, interface_json)
      {:ok, interface}
    end
  end

  defp update_interface(realm_name, interface_name, major_version) do
    with {:ok, interface_json} <-
           Engine.interface_source(realm_name, interface_name, major_version) do
      interface_params = Jason.decode!(interface_json, keys: :atoms)

      interface =
        %Interface{}
        |> Interface.changeset(interface_params)
        |> Ecto.Changeset.apply_action!(:insert)

      DB.update_interface(realm_name, interface)
    end
  end
end
