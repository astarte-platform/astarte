#
# This file is part of Astarte.
#
# Copyright 2018 - 2026 SECO Mind Srl
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

defmodule Astarte.RealmManagement.InterfacesTest do
  use ExUnitProperties

  use Astarte.Cases.Data, async: true

  import ExUnit.CaptureLog

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm

  alias Astarte.Helpers.Database

  alias Astarte.RealmManagement.Interfaces
  alias Astarte.RealmManagement.Interfaces.Core
  alias Astarte.RealmManagement.Interfaces.InterfacesListOptions

  @moduletag :interfaces

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

  describe "list_interfaces/2" do
    setup %{realm_name: realm_name, astarte_instance_id: astarte_instance_id} do
      interfaces =
        InterfaceGenerator.interface()
        |> StreamData.list_of(length: 3..10)
        |> Enum.at(0)
        |> Enum.uniq_by(& &1.interface_name)

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)

        for interface <- interfaces do
          capture_log(fn ->
            Core.delete_interface(realm_name, interface.name, interface.major_version)
          end)
        end
      end)

      installed_interfaces =
        for interface <- interfaces do
          {:ok, interface} = insert_interface_cleanly(realm_name, interface)
          interface
        end

      %{interfaces: installed_interfaces}
    end

    test "returns the names of the installed interfaces", context do
      %{realm_name: realm_name, interfaces: interfaces} = context
      expected_names = interfaces |> Enum.map(& &1.name) |> MapSet.new()

      assert {:ok, names} = Interfaces.list_interfaces(realm_name)
      names = MapSet.new(names)

      assert names == expected_names
    end

    test "returns the list of installed interfaces with the detailed option", context do
      %{realm_name: realm_name, interfaces: interfaces} = context
      opts = %InterfacesListOptions{detailed: true}
      expected = interfaces |> MapSet.new()
      assert {:ok, result} = Interfaces.list_interfaces(realm_name, opts)
      result = MapSet.new(result)

      assert expected == result
    end
  end

  describe "list_interface_major_versions/2" do
    setup %{realm_name: realm_name, astarte_instance_id: astarte_instance_id} do
      interface = InterfaceGenerator.interface() |> Enum.at(0)

      {:ok, installed_interface} = insert_interface_cleanly(realm_name, interface)

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)

        capture_log(fn ->
          Core.delete_interface(realm_name, interface.name, interface.major_version)
        end)
      end)

      %{interface: installed_interface}
    end

    test "returns installed major versions for an existing interface", %{
      realm_name: realm_name,
      interface: interface
    } do
      assert {:ok, [interface.major_version]} ==
               Interfaces.list_interface_major_versions(realm_name, interface.name)
    end

    test "returns error when interface does not exist", %{realm_name: realm_name} do
      assert {:error, :interface_not_found} ==
               Interfaces.list_interface_major_versions(realm_name, "com.some.RandomInterface")
    end
  end

  describe "interface creation" do
    @describetag :creation

    setup %{realm: realm, astarte_instance_id: astarte_instance_id} do
      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        capture_log(fn -> Core.delete_interface(realm, @interface_name, @interface_major) end)
      end)
    end

    test "succeeds with valid attrs", %{realm: realm} do
      assert {:ok, %Interface{} = interface} = Interfaces.install_interface(realm, @valid_attrs)

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
      assert {:ok, %Interface{} = _interface} = Interfaces.install_interface(realm, @valid_attrs)

      assert {:error, :already_installed_interface} =
               Interfaces.install_interface(realm, @valid_attrs)
    end

    test "fails when interface name collides after normalization", %{realm: realm} do
      new_name = "com.astarteplatform.Interface"

      normalized_attrs =
        @valid_attrs
        |> Map.put("interface_name", new_name)

      {:ok, %Interface{}} = Interfaces.install_interface(realm, normalized_attrs)

      colliding_normalized_attrs =
        @valid_attrs
        |> Map.put("interface_name", "com.astarte-platform.Interface")

      assert {:error, :interface_name_collision} =
               Interfaces.install_interface(realm, colliding_normalized_attrs)

      capture_log(fn ->
        Core.delete_interface(
          realm,
          new_name,
          @interface_major
        )
      end)
    end

    test "fails with invalid attrs", %{realm: realm} do
      assert {:error, changeset} =
               Interfaces.install_interface(realm, @invalid_attrs)

      assert [type: {"is invalid", _}] = changeset.errors
    end

    test "succeeds using a synchronous call", %{realm: realm} do
      assert {:ok, %Interface{} = interface} =
               Interfaces.install_interface(realm, @valid_attrs, async: false)

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
      insert_datastream_maximum_storage_retention!(realm, 1)

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
               Interfaces.install_interface(realm, iface_with_invalid_mappings)

      keyspace = Realm.keyspace_name(realm)

      %{group: "realm_config", key: "datastream_maximum_storage_retention", value: nil}
      |> KvStore.insert(prefix: keyspace)
    end
  end

  describe "interface update" do
    @describetag :update

    setup %{realm: realm, astarte_instance_id: astarte_instance_id} do
      {:ok, interface} = Interfaces.install_interface(realm, @valid_attrs)

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)

        capture_log(fn ->
          Core.delete_interface(realm, interface.name, interface.major_version)
        end)
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

      assert {:ok, interface} =
               Interfaces.fetch_interface(realm, @interface_name, @interface_major)

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

      assert {:ok, interface} =
               Interfaces.fetch_interface(realm, @interface_name, @interface_major)

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
                  ),
                max_runs: 10 do
        updated_interface_params =
          valid_update_interface |> Jason.encode!() |> Jason.decode!(keys: :atoms)

        {:ok, interface} = insert_interface_cleanly(realm, interface)

        assert :ok =
                 Interfaces.update_interface(
                   realm,
                   interface.name,
                   interface.major_version,
                   updated_interface_params
                 )

        {:ok, interface} =
          Interfaces.fetch_interface(realm, interface.name, interface.major_version)

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

        capture_log(fn ->
          Core.delete_interface(realm, interface.name, interface.major_version)
        end)
      end
    end

    property "does not allow major version changes", %{realm: realm} do
      check all interface <- InterfaceGenerator.interface(major_version: integer(0..8)),
                updated_interface <-
                  InterfaceGenerator.interface(
                    name: interface.name,
                    major_version: interface.major_version + 1
                  ),
                max_runs: 10 do
        interface_update =
          updated_interface |> Jason.encode!() |> Jason.decode!(keys: :atoms)

        {:ok, interface} = insert_interface_cleanly(realm, interface)

        assert {:error, :major_version_not_matching} =
                 Interfaces.update_interface(
                   realm,
                   interface.name,
                   interface.major_version,
                   interface_update
                 )

        capture_log(fn ->
          Core.delete_interface(realm, interface.name, interface.major_version)
        end)
      end
    end

    property "does not allow downgrade", %{realm: realm} do
      check all interface <-
                  InterfaceGenerator.interface(minor_version: integer(2..255)),
                updated_interface <-
                  InterfaceGenerator.interface(
                    name: interface.name,
                    major_version: interface.major_version,
                    minor_version: interface.minor_version - 1,
                    type: interface.type,
                    ownership: interface.ownership,
                    aggregation: interface.aggregation,
                    interface_id: interface.interface_id,
                    mappings: interface.mappings
                  ),
                max_runs: 10 do
        interface_update =
          updated_interface |> Jason.encode!() |> Jason.decode!(keys: :atoms)

        {:ok, interface} = insert_interface_cleanly(realm, interface)

        {:error, :downgrade_not_allowed} =
          Interfaces.update_interface(
            realm,
            interface.name,
            interface.major_version,
            interface_update
          )

        capture_log(fn ->
          Core.delete_interface(realm, interface.name, interface.major_version)
        end)
      end
    end
  end

  describe "interface deletion" do
    @describetag :deletion

    setup %{realm: realm, astarte_instance_id: astarte_instance_id} do
      {:ok, interface} = Interfaces.install_interface(realm, @valid_attrs)

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)

        capture_log(fn ->
          Core.delete_interface(realm, interface.name, interface.major_version)
        end)
      end)

      :ok
    end

    test "succeeds with valid interface", %{realm: realm} do
      assert :ok = Interfaces.delete_interface(realm, @interface_name, @interface_major)

      assert {:error, :interface_not_found} =
               Interfaces.fetch_interface(realm, @interface_name, @interface_major)
    end

    test "fails if major version is other than 0", context do
      %{realm: realm, astarte_instance_id: astarte_instance_id} = context
      new_interface_major = 1

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)

        capture_log(fn ->
          Core.delete_interface(realm, @interface_name, new_interface_major)
        end)
      end)

      major_attrs =
        @valid_attrs
        |> Map.put("version_major", new_interface_major)

      assert {:ok, %Interface{}} = Interfaces.install_interface(realm, major_attrs)

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

  defp insert_interface_cleanly(realm_name, interface) do
    capture_log(fn ->
      Core.delete_interface(realm_name, interface.name, interface.major_version)
    end)

    interface_params =
      interface
      |> Jason.encode!()
      |> Jason.decode!()

    case Interfaces.install_interface(realm_name, interface_params) do
      {:ok, installed_interface} ->
        {:ok, installed_interface}

      {:error, reason} ->
        raise "Failed to install interface #{interface.name} v#{interface.major_version}: #{inspect(reason)}"
    end
  end
end
