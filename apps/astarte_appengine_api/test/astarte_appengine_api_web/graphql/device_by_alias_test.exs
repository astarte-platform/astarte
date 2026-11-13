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
defmodule Astarte.AppEngine.APIWeb.GraphQL.DeviceByAliasTest do
  use Astarte.AppEngine.API.Cases.Data, async: true
  use Astarte.AppEngine.API.Cases.Conn
  use Astarte.Auth.Cases.AuthorizationModel

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Groups
  alias Astarte.AppEngine.API.Helpers.JWT
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.DataAccess.Device, as: DatabaseDevice
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  @id_query "query ($alias: String!) { deviceByAlias(alias: $alias) { id } }"

  # the REST field names as aliases, so that the response can be compared with the REST one
  @status_query """
  query ($alias: String!) {
    deviceByAlias(alias: $alias) {
      id
      connected
      introspection { ...interfaceInfo }
      previous_interfaces: previousInterfaces { ...interfaceInfo }
      aliases { key value }
      attributes { key value }
      groups
      total_received_msgs: totalReceivedMsgs
      total_received_bytes: totalReceivedBytes
      last_connection: lastConnection
      last_disconnection: lastDisconnection
      first_registration: firstRegistration
      first_credentials_request: firstCredentialsRequest
      last_seen_ip: lastSeenIp
      last_credentials_request_ip: lastCredentialsRequestIp
      credentials_inhibited: credentialsInhibited
      deletion_in_progress: deletionInProgress
    }
  }

  fragment interfaceInfo on InterfaceInfo {
    name
    major
    minor
    exchanged_msgs: exchangedMsgs
    exchanged_bytes: exchangedBytes
  }
  """

  @forbidden "Forbidden: OpenFGA denied access for this action"

  setup_all %{realm_name: realm_name, store_id: store_id} do
    JWT.install_public_key!(realm_name)

    device_id = CoreDevice.random_device_id()

    Repo.insert!(
      %DatabaseDevice{
        device_id: device_id,
        attributes: %{"plant" => "turin"},
        connected: true,
        introspection: %{"com.example.Sensor" => 1},
        introspection_minor: %{"com.example.Sensor" => 2},
        exchanged_msgs_by_interface: %{{"com.example.Sensor", 1} => 10},
        exchanged_bytes_by_interface: %{{"com.example.Sensor", 1} => 1000},
        total_received_msgs: 10,
        total_received_bytes: 1000,
        first_registration: ~U[2026-01-10 09:00:00.000Z],
        last_connection: ~U[2026-11-05 08:00:00.000Z],
        last_seen_ip: {198, 51, 100, 7},
        inhibit_credentials_request: false
      },
      prefix: Realm.keyspace_name(realm_name)
    )

    device_id = CoreDevice.encode_device_id(device_id)
    device_alias = "press#{System.unique_integer([:positive])}"

    # through the domain, so that the alias is also registered as a name of the realm
    {:ok, _status} =
      Device.merge_device_status(realm_name, device_id, %{"aliases" => %{"name" => device_alias}})

    {:ok, _group} =
      Groups.create_group(realm_name, %{"group_name" => "line4", "devices" => [device_id]})

    write_tuples!(store_id, [
      %{user: "user:#{realm_name}/grantee", relation: "observer", object: "realm:#{realm_name}"},
      %{
        user: "user:#{realm_name}/device_grantee",
        relation: "observer",
        object: "device:#{realm_name}/#{device_id}"
      },
      %{
        user: "user:#{realm_name}/group_grantee",
        relation: "observer",
        object: "device_group:#{realm_name}/line4"
      }
    ])

    %{device_id: device_id, device_alias: device_alias}
  end

  setup %{conn: conn, realm_name: realm_name} do
    {:ok, conn: put_req_header(conn, "astarte-realm", realm_name)}
  end

  test "a realm role in the token grants the query", context do
    %{conn: conn, device_id: id, device_alias: device_alias} = context
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{"data" => %{"deviceByAlias" => %{"id" => ^id}}} =
             query(conn, token, @id_query, device_alias)
  end

  test "a realm role stored in OpenFGA grants the query", context do
    %{conn: conn, device_id: id, device_alias: device_alias} = context
    token = JWT.gen_jwt_token_with_roles([], "grantee")

    assert %{"data" => %{"deviceByAlias" => %{"id" => ^id}}} =
             query(conn, token, @id_query, device_alias)
  end

  test "a role on the device doesn't grant the query", %{conn: conn, device_alias: device_alias} do
    token = JWT.gen_jwt_token_with_roles([], "device_grantee")

    conn |> query(token, @id_query, device_alias) |> assert_error(@forbidden)
  end

  test "a role on one of the device's groups doesn't grant the query",
       %{conn: conn, device_alias: device_alias} do
    token = JWT.gen_jwt_token_with_roles([], "group_grantee")

    conn |> query(token, @id_query, device_alias) |> assert_error(@forbidden)
  end

  test "an alias that doesn't exist is not found", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    conn |> query(token, @id_query, "missing") |> assert_error("device_not_found")
  end

  test "an alias that doesn't exist is forbidden without a role", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles([])

    conn |> query(token, @id_query, "missing") |> assert_error(@forbidden)
  end

  test "returns the device status of the REST API", context do
    %{conn: conn, realm_name: realm_name, device_alias: device_alias} = context
    token = JWT.gen_jwt_token_with_roles(["observer"])

    %{"data" => %{"deviceByAlias" => device}} = query(conn, token, @status_query, device_alias)

    rest_device =
      conn
      |> put_req_header("authorization", "bearer #{JWT.gen_jwt_all_access_token()}")
      |> get("/v1/#{realm_name}/devices-by-alias/#{device_alias}")
      |> json_response(200)
      |> Map.fetch!("data")

    assert rest_shape(device) == rest_device
  end

  defp query(conn, token, query, device_alias) do
    conn
    |> put_req_header("authorization", "bearer #{token}")
    |> put_req_header("content-type", "application/json")
    |> post("/v1/graphql", Jason.encode!(%{query: query, variables: %{alias: device_alias}}))
    |> json_response(200)
  end

  defp assert_error(response, message) do
    assert %{"data" => %{"deviceByAlias" => nil}, "errors" => [%{"message" => ^message}]} =
             response
  end

  # REST returns aliases, attributes and introspection as objects keyed by name
  defp rest_shape(device) do
    device
    |> Map.update!("aliases", &entries_to_map/1)
    |> Map.update!("attributes", &entries_to_map/1)
    |> Map.update!("introspection", &Map.new(&1, fn info -> Map.pop!(info, "name") end))
  end

  defp entries_to_map(entries), do: Map.new(entries, &{&1["key"], &1["value"]})
end
