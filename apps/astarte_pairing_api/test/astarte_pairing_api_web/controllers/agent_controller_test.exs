#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.APIWeb.AgentControllerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Astarte.Pairing.APIWeb.ConnCase, async: true

  alias Astarte.Pairing.APIWeb.Helpers.JWTTestHelper

  @hw_id "2imLILqtRP2vq0ZVy-TGRQ"
  @hw_id_256 "ova1YgZZZo3p_2m8UjJ_c3sOOmpLh3GOc0CARFwE-V4"
  @empty_invalid_hw_id ""
  @short_invalid_hw_id "YQ"
  @invalid_hw_id "5GGciygQUcHZqXyc1BNeC%"

  @create_attrs %{"hw_id" => @hw_id}
  @create_attrs_256 %{"hw_id" => @hw_id_256}
  @empty_invalid_attrs %{"hw_id" => @empty_invalid_hw_id}
  @short_invalid_attrs %{"hw_id" => @short_invalid_hw_id}
  @bad_encoding_invalid_attrs %{"hw_id" => @invalid_hw_id}

  describe "register device" do
    setup [:authorize_conn]

    test "renders credentials_secret when data is valid", ctx do
      %{conn: conn, realm_name: realm_name} = ctx

      conn = post(conn, agent_path(conn, :create, realm_name), data: @create_attrs)
      assert %{"credentials_secret" => credentials_secret} = json_response(conn, 201)["data"]
      assert is_binary(credentials_secret)
    end

    test "renders credentials_secret when data is valid and includes initial_introspection",
         ctx do
      %{conn: conn, realm_name: realm_name} = ctx

      initial_introspection = %{
        "org.astarteplatform.Values" => %{"major" => 0, "minor" => 4},
        "org.astarteplatform.OtherValues" => %{"major" => 1, "minor" => 0}
      }

      attrs = Map.put(@create_attrs, "initial_introspection", initial_introspection)

      conn = post(conn, agent_path(conn, :create, realm_name), data: attrs)
      assert %{"credentials_secret" => credentials_secret} = json_response(conn, 201)["data"]
      assert is_binary(credentials_secret)
    end

    test "renders credentials_secret when data is valid and hardware id is 256 bits long", ctx do
      %{conn: conn, realm_name: realm_name} = ctx

      conn = post(conn, agent_path(conn, :create, realm_name), data: @create_attrs_256)
      assert %{"credentials_secret" => credentials_secret} = json_response(conn, 201)["data"]
      assert is_binary(credentials_secret)
    end

    test "renders errors when data is invalid", ctx do
      %{conn: conn, realm_name: realm_name} = ctx

      conn = post(conn, agent_path(conn, :create, realm_name), data: @empty_invalid_attrs)
      assert json_response(conn, 422)["errors"] == %{"hw_id" => ["can't be blank"]}
    end

    test "renders errors when initial_introspection is invalid", ctx do
      %{conn: conn, realm_name: realm_name} = ctx

      invalid_initial_introspection = %{"org.astarteplatform.Values" => %{"major" => 2}}

      attrs = Map.put(@create_attrs, "initial_introspection", invalid_initial_introspection)

      conn = post(conn, agent_path(conn, :create, realm_name), data: attrs)

      assert json_response(conn, 422)["errors"] == %{
               "initial_introspection" => [
                 "has invalid format for interface org.astarteplatform.Values"
               ]
             }
    end

    test "renders errors when hardware id is too short", %{conn: conn, realm_name: realm_name} do
      conn = post(conn, agent_path(conn, :create, realm_name), data: @short_invalid_attrs)

      assert json_response(conn, 422)["errors"] == %{
               "hw_id" => ["is not a valid base64 encoded 128 bits id"]
             }
    end

    test "renders errors when hardware id is not valid base64", %{
      conn: conn,
      realm_name: realm_name
    } do
      conn = post(conn, agent_path(conn, :create, realm_name), data: @bad_encoding_invalid_attrs)

      assert json_response(conn, 422)["errors"] == %{
               "hw_id" => ["is not a valid base64 encoded 128 bits id"]
             }
    end

    test "renders errors when device already exists", %{
      conn: conn,
      realm_name: realm_name
    } do
      interfaces = []
      device = Astarte.Core.Generators.Device.device(interfaces: interfaces) |> Enum.at(0)
      Astarte.Helpers.Device.insert_device_cleanly(realm_name, device, interfaces)

      existing_attrs = %{"hw_id" => device.encoded_id}
      conn = post(conn, agent_path(conn, :create, realm_name), data: existing_attrs)
      assert json_response(conn, 422)["errors"] == %{"detail" => "Device already registered"}
    end

    test "renders errors when unauthorized", ctx do
      %{conn: conn, realm_name: realm_name} = ctx

      conn =
        conn
        |> delete_req_header("authorization")
        |> post(agent_path(conn, :create, realm_name), data: @create_attrs)

      assert json_response(conn, 401)["errors"] == %{"detail" => "Unauthorized"}
    end

    test "renders forbidden error when realm does not exist", ctx do
      %{conn: conn} = ctx

      realm_name = "unknown"

      conn = post(conn, agent_path(conn, :create, realm_name), data: @create_attrs)

      assert json_response(conn, 403)["errors"] == %{"detail" => "Forbidden"}
    end
  end

  describe "unregister device" do
    setup [:authorize_conn]

    @unexisting_device_id "Lwf5dutoSuqS0kbG44-BOw"

    test "successful call", %{conn: conn, realm_name: realm_name, device: device} do
      conn = delete(conn, agent_path(conn, :delete, realm_name, device.encoded_id))
      assert response(conn, 204) == ""
    end

    test "renders errors when device does not exist", ctx do
      %{conn: conn, realm_name: realm_name} = ctx
      conn = delete(conn, agent_path(conn, :delete, realm_name, @unexisting_device_id))
      assert json_response(conn, 404)["errors"] == %{"detail" => "Device not found"}
    end

    test "renders errors when unauthorized", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      conn =
        conn
        |> delete_req_header("authorization")
        |> delete(agent_path(conn, :delete, realm_name, device.encoded_id))

      assert json_response(conn, 401)["errors"] == %{"detail" => "Unauthorized"}
    end

    test "renders forbidden error when realm does not exist", ctx do
      %{conn: conn, device: device} = ctx

      realm_name = "unknown"

      conn = delete(conn, agent_path(conn, :delete, realm_name, device.encoded_id))

      assert json_response(conn, 403)["errors"] == %{"detail" => "Forbidden"}
    end
  end

  defp authorize_conn(%{conn: conn}) do
    jwt = JWTTestHelper.gen_jwt_all_access_token()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "bearer #{jwt}")

    {:ok, conn: conn}
  end
end
