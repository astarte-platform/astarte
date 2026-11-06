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
defmodule Astarte.AppEngine.APIWeb.GraphQL.DeviceTest do
  use Astarte.AppEngine.API.Cases.Data, async: true
  use Astarte.AppEngine.API.Cases.Conn
  use Astarte.Auth.Cases.AuthorizationModel

  alias Astarte.AppEngine.API.Groups
  alias Astarte.AppEngine.API.Helpers.JWT
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.DataAccess.Device
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  @id_query "query ($id: String!) { device(deviceId: $id) { id } }"

  # the REST field names as aliases, so that the response can be compared with the REST one
  @status_query """
  query ($id: String!) {
    device(deviceId: $id) {
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
    other_device_id = CoreDevice.random_device_id()
    keyspace = Realm.keyspace_name(realm_name)

    Repo.insert!(
      %Device{
        device_id: device_id,
        aliases: %{"name" => "press"},
        attributes: %{"plant" => "turin"},
        connected: true,
        introspection: %{"com.example.Sensor" => 1},
        introspection_minor: %{"com.example.Sensor" => 2},
        old_introspection: %{{"com.example.Sensor", 0} => 4},
        exchanged_msgs_by_interface: %{{"com.example.Sensor", 1} => 10},
        exchanged_bytes_by_interface: %{{"com.example.Sensor", 1} => 1000},
        total_received_msgs: 10,
        total_received_bytes: 1000,
        first_registration: ~U[2026-01-10 09:00:00.000Z],
        last_connection: ~U[2026-11-05 08:00:00.000Z],
        last_seen_ip: {198, 51, 100, 7},
        inhibit_credentials_request: false
      },
      prefix: keyspace
    )

    Repo.insert!(%Device{device_id: other_device_id}, prefix: keyspace)

    device_id = CoreDevice.encode_device_id(device_id)
    other_device_id = CoreDevice.encode_device_id(other_device_id)

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

    %{device_id: device_id, other_device_id: other_device_id}
  end

  setup %{conn: conn, realm_name: realm_name} do
    {:ok, conn: put_req_header(conn, "astarte-realm", realm_name)}
  end

  test "a realm role in the token grants the device query", %{conn: conn, device_id: id} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{"data" => %{"device" => %{"id" => ^id}}} = query(conn, token, @id_query, id)
  end

  test "a realm role stored in OpenFGA grants the device query", %{conn: conn, device_id: id} do
    token = JWT.gen_jwt_token_with_roles([], "grantee")

    assert %{"data" => %{"device" => %{"id" => ^id}}} = query(conn, token, @id_query, id)
  end

  test "a role on the device grants the device query", %{conn: conn, device_id: id} do
    token = JWT.gen_jwt_token_with_roles([], "device_grantee")

    assert %{"data" => %{"device" => %{"id" => ^id}}} = query(conn, token, @id_query, id)
  end

  test "a role on another device doesn't grant the device query",
       %{conn: conn, other_device_id: id} do
    token = JWT.gen_jwt_token_with_roles([], "device_grantee")

    conn |> query(token, @id_query, id) |> assert_error(@forbidden)
  end

  test "a role on one of the device's groups doesn't grant the device query",
       %{conn: conn, device_id: id} do
    token = JWT.gen_jwt_token_with_roles([], "group_grantee")

    conn |> query(token, @id_query, id) |> assert_error(@forbidden)
  end

  test "a device that doesn't exist is not found", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])
    id = CoreDevice.random_device_id() |> CoreDevice.encode_device_id()

    conn |> query(token, @id_query, id) |> assert_error("device_not_found")
  end

  test "a device that doesn't exist is forbidden without a role", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles([])
    id = CoreDevice.random_device_id() |> CoreDevice.encode_device_id()

    conn |> query(token, @id_query, id) |> assert_error(@forbidden)
  end

  test "an invalid device id is rejected", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    conn |> query(token, @id_query, "notadeviceid") |> assert_error("Invalid argument: device_id")
  end

  test "returns the device status of the REST API",
       %{conn: conn, realm_name: realm_name, device_id: id} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    %{"data" => %{"device" => device}} = query(conn, token, @status_query, id)

    rest_device =
      conn
      |> put_req_header("authorization", "bearer #{JWT.gen_jwt_all_access_token()}")
      |> get("/v1/#{realm_name}/devices/#{id}")
      |> json_response(200)
      |> Map.fetch!("data")

    assert rest_shape(device) == rest_device
  end

  defp query(conn, token, query, device_id) do
    conn
    |> put_req_header("authorization", "bearer #{token}")
    |> put_req_header("content-type", "application/json")
    |> post("/v1/graphql", Jason.encode!(%{query: query, variables: %{id: device_id}}))
    |> json_response(200)
  end

  defp assert_error(response, message) do
    assert %{"data" => %{"device" => nil}, "errors" => [%{"message" => ^message}]} = response
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
