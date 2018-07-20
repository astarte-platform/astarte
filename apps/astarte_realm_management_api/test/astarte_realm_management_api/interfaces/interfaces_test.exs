#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.RealmManagement.API.InterfacesTest do
  use Astarte.RealmManagement.API.DataCase

  alias Astarte.RealmManagement.API.Interfaces
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping
  @realm "testrealm"
  @interface_name "com.Some.Interface"
  @interface_major 2
  @valid_attrs %{
    "interface_name" => @interface_name,
    "version_major" => 2,
    "version_minor" => 1,
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
    test "succeeds with valid attrs" do
      assert {:ok, %Interface{} = interface} = Interfaces.create_interface(@realm, @valid_attrs)

      assert %Interface{
               name: @interface_name,
               major_version: @interface_major,
               minor_version: 1,
               type: :properties,
               ownership: :device,
               mappings: [mapping]
             } = interface

      assert %Mapping{
               endpoint: "/test",
               value_type: :integer
             } = mapping

      assert [@interface_name] = Interfaces.list_interfaces!(@realm)
    end

    test "fails with already installed interface" do
      assert {:ok, %Interface{} = _interface} = Interfaces.create_interface(@realm, @valid_attrs)

      assert {:error, :already_installed_interface} =
               Interfaces.create_interface(@realm, @valid_attrs)
    end

    test "fails with invalid attrs" do
      assert {:error, %Ecto.Changeset{errors: [type: _]}} =
               Interfaces.create_interface(@realm, @invalid_attrs)
    end
  end

  describe "interface update" do
    setup do
      {:ok, %Interface{}} = Interfaces.create_interface(@realm, @valid_attrs)
      :ok
    end

    test "succeeds with valid attrs" do
      doc = "some doc"

      update_attrs =
        @valid_attrs
        |> Map.put("version_minor", 10)
        |> Map.put("doc", doc)

      assert {:ok, :started} ==
               Interfaces.update_interface(
                 @realm,
                 @interface_name,
                 @interface_major,
                 update_attrs
               )

      assert interface_source =
               Interfaces.get_interface!(@realm, @interface_name, @interface_major)

      assert {:ok, map} = Poison.decode(interface_source)

      assert {:ok, interface} =
               Interface.changeset(%Interface{}, map) |> Ecto.Changeset.apply_action(:insert)

      assert %Interface{
               name: "com.Some.Interface",
               major_version: 2,
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

      assert ["com.Some.Interface"] = Interfaces.list_interfaces!(@realm)
    end

    test "fails with not installed interface" do
      update_attrs =
        @valid_attrs
        |> Map.put("interface_name", "com.NotExisting")

      assert {:error, :interface_major_version_does_not_exist} =
               Interfaces.update_interface(
                 @realm,
                 "com.NotExisting",
                 @interface_major,
                 update_attrs
               )
    end

    test "fails with invalid attrs" do
      assert {:error, %Ecto.Changeset{errors: [type: _]}} =
               Interfaces.create_interface(@realm, @invalid_attrs)
    end
  end
end
