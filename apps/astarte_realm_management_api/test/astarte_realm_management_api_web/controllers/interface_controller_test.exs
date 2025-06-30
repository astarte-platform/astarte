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

defmodule Astarte.RealmManagement.APIWeb.InterfaceControllerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.RealmManagement.APIWeb.ConnCase

  @moduletag :interfaces

  import Astarte.Helpers.Database
  import ExUnit.CaptureLog

  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.Helpers.Database
  alias Astarte.RealmManagement.API.Interfaces.Core

  @interface_name "com.Some.Interface"
  @interface_major 0
  @interface_major_str Integer.to_string(@interface_major)
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

  setup %{realm: realm, astarte_instance_id: astarte_instance_id} do
    on_exit(fn ->
      Database.setup_database_access(astarte_instance_id)
      capture_log(fn -> Core.delete_interface(realm, @interface_name, @interface_major) end)
    end)

    :ok
  end

  describe "index" do
    @describetag :index

    test "lists empty interfaces", %{auth_conn: conn, realm: realm} do
      conn = get(conn, interface_path(conn, :index, realm))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists interface after installing it", %{auth_conn: conn, realm: realm} do
      post_conn =
        post(conn, interface_path(conn, :create, realm),
          data: @valid_attrs,
          async_operation: "false"
        )

      assert response(post_conn, 201) == ""

      list_conn = get(conn, interface_path(conn, :index, realm))
      assert json_response(list_conn, 200)["data"] == [@interface_name]
      Core.delete_interface(realm, @interface_name, @interface_major)
    end
  end

  describe "show" do
    @describetag :show

    setup %{auth_conn: conn, realm: realm} do
      post_conn =
        post(conn, interface_path(conn, :create, realm),
          data: @valid_attrs,
          async_operation: "false"
        )

      assert response(post_conn, 201) == ""

      :ok
    end

    test "existing interface", %{auth_conn: conn, realm: realm} do
      show_conn =
        get(conn, interface_path(conn, :show, realm, @interface_name, @interface_major_str))

      assert json_response(show_conn, 200)["data"]["interface_name"] == @interface_name
    end

    test "renders error on non-existing interface", %{auth_conn: conn, realm: realm} do
      conn =
        get(conn, interface_path(conn, :show, realm, "com.Nonexisting", @interface_major_str))

      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "create interface" do
    @describetag :creation

    test "renders interface when data is valid", %{auth_conn: conn, realm: realm} do
      post_conn =
        post(conn, interface_path(conn, :create, realm),
          data: @valid_attrs,
          async_operation: "false"
        )

      assert response(post_conn, 201) == ""

      get_conn =
        get(conn, interface_path(conn, :show, realm, @interface_name, @interface_major_str))

      assert %{"interface_name" => @interface_name, "version_major" => @interface_major} =
               json_response(get_conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{auth_conn: conn, realm: realm} do
      conn =
        post(conn, interface_path(conn, :create, realm),
          data: @invalid_attrs,
          async_operation: "false"
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders error when interface is already installed", %{auth_conn: conn, realm: realm} do
      post_conn =
        post(conn, interface_path(conn, :create, realm),
          data: @valid_attrs,
          async_operation: "false"
        )

      assert response(post_conn, 201) == ""

      post2_conn = post(conn, interface_path(conn, :create, realm), data: @valid_attrs)
      assert json_response(post2_conn, 409)["errors"] != %{}
    end

    test "renders error on mapping with higher database_retention_ttl than the maximum", %{
      auth_conn: conn,
      realm: realm
    } do
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

      conn =
        post(conn, interface_path(conn, :create, realm),
          data: iface_with_invalid_mappings,
          async_operation: "false"
        )

      assert json_response(conn, 422)["errors"] != %{}

      keyspace = Realm.keyspace_name(realm)

      %{group: "realm_config", key: "datastream_maximum_storage_retention", value: nil}
      |> KvStore.insert(prefix: keyspace)
    end

    test "fails when interface name collides after normalization", %{
      auth_conn: conn,
      realm: realm
    } do
      interface_name = "com.astarteplatform.Interface"

      first_attrs =
        @valid_attrs
        |> Map.put("interface_name", interface_name)

      post_conn =
        post(conn, interface_path(conn, :create, realm),
          data: first_attrs,
          async_operation: "false"
        )

      assert response(post_conn, 201) == ""

      get_conn =
        get(conn, interface_path(conn, :show, realm, interface_name, @interface_major_str))

      assert json_response(get_conn, 200)["data"] == first_attrs

      colliding_name = "com.astarte-platform.Interface"

      colliding_attrs =
        @valid_attrs
        |> Map.put("interface_name", colliding_name)

      post_conn =
        post(conn, interface_path(conn, :create, realm),
          data: colliding_attrs,
          async_operation: "false"
        )

      assert json_response(post_conn, 409)["errors"]["detail"] ==
               "Interface name collision detected. Make sure that the difference between two interface names is not limited to the casing or the presence of hyphens."

      Core.delete_interface(realm, interface_name, @interface_major)
    end
  end

  describe "update" do
    @describetag :update

    setup %{auth_conn: conn, realm: realm} do
      post_conn =
        post(conn, interface_path(conn, :create, realm),
          data: @valid_attrs,
          async_operation: "false"
        )

      assert response(post_conn, 201) == ""

      :ok
    end

    test "updates interface when data is valid", %{auth_conn: conn, realm: realm} do
      new_mapping = %{"endpoint" => "/other", "type" => "string"}
      updated_mappings = [new_mapping | @valid_attrs["mappings"]]
      new_minor = @valid_attrs["version_minor"] + 1

      update_attrs = %{
        @valid_attrs
        | "version_minor" => new_minor,
          "mappings" => updated_mappings
      }

      update_conn =
        put(
          conn,
          interface_path(conn, :update, realm, @interface_name, @interface_major_str),
          data: update_attrs
        )

      assert response(update_conn, 204)

      get_conn =
        get(conn, interface_path(conn, :show, realm, @interface_name, @interface_major_str))

      assert json_response(get_conn, 200)["data"] == update_attrs
    end

    test "renders errors when data is invalid", %{auth_conn: conn, realm: realm} do
      conn =
        put(
          conn,
          interface_path(conn, :update, realm, @interface_name, @interface_major_str),
          data: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders error when major is not a number", %{auth_conn: conn, realm: realm} do
      conn =
        put(
          conn,
          interface_path(conn, :update, realm, @interface_name, "notanumber"),
          data: @valid_attrs
        )

      assert json_response(conn, 404)["errors"] != %{}
    end

    test "renders error when name doesn't match", %{auth_conn: conn, realm: realm} do
      conn =
        put(
          conn,
          interface_path(conn, :update, realm, "com.Other.Interface", @interface_major_str),
          data: @valid_attrs
        )

      assert json_response(conn, 409)["errors"] != %{}
    end

    test "renders error when major doesn't match", %{auth_conn: conn, realm: realm} do
      conn =
        put(
          conn,
          interface_path(conn, :update, realm, @interface_name, "42"),
          data: @valid_attrs
        )

      assert json_response(conn, 409)["errors"] != %{}
    end

    test "renders error when interface doesn't exist", %{auth_conn: conn, realm: realm} do
      other_interface = "com.Other"
      attrs = %{@valid_attrs | "interface_name" => other_interface}

      conn =
        put(
          conn,
          interface_path(conn, :update, realm, other_interface, @interface_major_str),
          data: attrs
        )

      assert json_response(conn, 404)["errors"] != %{}
    end

    test "renders error when minor version is not increased", %{auth_conn: conn, realm: realm} do
      new_mapping = %{"endpoint" => "/other", "type" => "string"}
      updated_mappings = [new_mapping | @valid_attrs["mappings"]]

      update_attrs = %{
        @valid_attrs
        | "mappings" => updated_mappings
      }

      update_conn =
        put(
          conn,
          interface_path(conn, :update, realm, @interface_name, @interface_major_str),
          data: update_attrs
        )

      assert json_response(update_conn, 409)["errors"]["detail"] ==
               "Interface minor version was not increased"
    end

    test "renders error minor version is decreased", %{auth_conn: conn, realm: realm} do
      new_mapping = %{"endpoint" => "/other", "type" => "string"}
      updated_mappings = [new_mapping | @valid_attrs["mappings"]]
      new_minor = @valid_attrs["version_minor"] - 1

      update_attrs = %{
        @valid_attrs
        | "version_minor" => new_minor,
          "mappings" => updated_mappings
      }

      update_conn =
        put(
          conn,
          interface_path(conn, :update, realm, @interface_name, @interface_major_str),
          data: update_attrs
        )

      assert json_response(update_conn, 409)["errors"]["detail"] ==
               "Interface downgrade not allowed"
    end

    test "renders error when mappings have missing endpoints", %{auth_conn: conn, realm: realm} do
      update_attrs = %{
        @valid_attrs
        | "version_minor" => @valid_attrs["version_minor"] + 1,
          "mappings" => [
            %{
              "endpoint" => "/new_endpoint",
              "type" => "integer"
            }
          ]
      }

      update_conn =
        put(
          conn,
          interface_path(conn, :update, realm, @interface_name, @interface_major_str),
          data: update_attrs
        )

      assert json_response(update_conn, 409)["errors"]["detail"] ==
               "Interface update has missing endpoints"
    end

    test "renders error when mappings have incompatible changes", %{auth_conn: conn, realm: realm} do
      update_attrs = %{
        @valid_attrs
        | "version_minor" => @valid_attrs["version_minor"] + 1,
          "mappings" => [
            %{
              "endpoint" => "/test",
              # Changing the type from integer to string
              "type" => "string"
            }
          ]
      }

      update_conn =
        put(
          conn,
          interface_path(conn, :update, realm, @interface_name, @interface_major_str),
          data: update_attrs
        )

      assert json_response(update_conn, 409)["errors"]["detail"] ==
               "Interface update contains incompatible endpoint changes"
    end

    test "renders error when type changes", %{auth_conn: conn, realm: realm} do
      update_attrs = %{
        @valid_attrs
        | "version_minor" => @valid_attrs["version_minor"] + 1,
          # Changed type
          "type" => "datastream"
      }

      update_conn =
        put(
          conn,
          interface_path(conn, :update, realm, @interface_name, @interface_major_str),
          data: update_attrs
        )

      assert json_response(update_conn, 409)["errors"]["detail"] == "Invalid update"
    end

    test "renders error when ownership changes", %{auth_conn: conn, realm: realm} do
      update_attrs = %{
        @valid_attrs
        | "version_minor" => @valid_attrs["version_minor"] + 1,
          # Changed ownership
          "ownership" => "server"
      }

      update_conn =
        put(
          conn,
          interface_path(conn, :update, realm, @interface_name, @interface_major_str),
          data: update_attrs
        )

      assert json_response(update_conn, 409)["errors"]["detail"] ==
               "Invalid update"
    end
  end

  describe "delete" do
    @describetag :deletion

    test "deletes existing interface", %{auth_conn: conn, realm: realm} do
      post_conn =
        post(conn, interface_path(conn, :create, realm),
          data: @valid_attrs,
          async_operation: "false"
        )

      assert response(post_conn, 201) == ""

      delete_conn =
        delete(conn, interface_path(conn, :delete, realm, @interface_name, @interface_major_str))

      assert response(delete_conn, 204) == ""
    end

    test "fails if major version is other than 0", %{auth_conn: conn, realm: realm} do
      new_interface_major = 1

      major_attrs =
        @valid_attrs
        |> Map.put("version_major", new_interface_major)

      post_conn =
        post(conn, interface_path(conn, :create, realm),
          data: major_attrs,
          async_operation: "false"
        )

      assert response(post_conn, 201) == ""

      delete_conn =
        delete(
          conn,
          interface_path(
            conn,
            :delete,
            realm,
            @interface_name,
            Integer.to_string(new_interface_major)
          )
        )

      assert json_response(delete_conn, 403)["errors"]["detail"] ==
               "Interface can't be deleted"
    end

    test "renders error on non-existing interface", %{auth_conn: conn, realm: realm} do
      delete_conn =
        delete(
          conn,
          interface_path(conn, :delete, realm, "com.Nonexisting", @interface_major_str)
        )

      assert json_response(delete_conn, 404)["errors"] != %{}
    end
  end
end
