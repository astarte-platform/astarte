#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.AppEngine.APIWeb.InterfaceControllerTest do
  @moduledoc false
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.KvStore
  alias Astarte.AppEngine.API.Device
  alias Astarte.Helpers.JWT

  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Astarte.Cases.Conn
  use ExUnitProperties
  use Mimic

  import Astarte.InterfaceUpdateGenerators
  import Astarte.Helpers.Device

  setup_all %{realm_name: realm} do
    keyspace = Realm.keyspace_name(realm)

    %{
      group: "auth",
      key: "jwt_public_key_pem",
      value: JWT.public_key_pem()
    }
    |> KvStore.insert(prefix: keyspace)

    :ok
  end

  setup %{conn: conn} do
    authorized_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "bearer #{JWT.gen_jwt_all_access_token()}")

    {:ok, auth_conn: authorized_conn}
  end

  describe "Interface controller" do
    property "publish calls device module", context do
      %{realm_name: realm_name, interfaces: interfaces, device: device, auth_conn: conn} = context
      valid_interfaces_for_update = interfaces |> Enum.filter(&(&1.ownership == :server))

      check all interface_to_update <- member_of(valid_interfaces_for_update),
                mapping_update <- valid_mapping_update_for(interface_to_update) do
        path =
          interface_values_path(
            conn,
            :update,
            realm_name,
            device.encoded_id,
            interface_to_update.name,
            path_tokens(mapping_update.path)
          )

        Device
        |> allow(self(), conn.owner)
        |> expect(:update_interface_values, fn realm,
                                               device_id,
                                               interface_name,
                                               path,
                                               value,
                                               _parameters ->
          assert realm == realm_name
          assert device_id == device.encoded_id
          assert interface_name == interface_to_update.name
          assert value == mapping_update.value
          assert "/" <> path == mapping_update.path

          {:ok, %InterfaceValues{data: value}}
        end)

        conn = post(conn, path, %{"data" => mapping_update.value})

        assert json_response(conn, 200)["data"] == mapping_update.value
      end
    end

    property "read calls device module", context do
      %{realm_name: realm_name, interfaces: interfaces, device: device, auth_conn: conn} = context

      check all interface <- member_of(interfaces),
                mapping <- member_of(interface.mappings),
                path <- path_from_endpoint(mapping.endpoint),
                value <- valid_update_value_for(mapping.value_type) do
        interface_name = interface.name
        device_id = device.encoded_id

        request_path =
          interface_values_path(
            conn,
            :show,
            realm_name,
            device.encoded_id,
            interface_name,
            path_tokens(path)
          )

        Device
        |> allow(self(), conn.owner)
        |> expect(:get_interface_values!, fn ^realm_name, ^device_id, ^interface_name, _params ->
          {:ok, %InterfaceValues{data: value}}
        end)

        conn = get(conn, request_path)
        assert json_response(conn, 200)["data"] == value
      end
    end

    property "delete calls the device module", context do
      %{realm_name: realm_name, interfaces: interfaces, device: device, auth_conn: conn} = context

      check all interface <- member_of(interfaces),
                mapping <- member_of(interface.mappings),
                path <- path_from_endpoint(mapping.endpoint) do
        interface_name = interface.name
        device_id = device.encoded_id

        request_path =
          interface_values_path(
            conn,
            :delete,
            realm_name,
            device.encoded_id,
            interface_name,
            path_tokens(path)
          )

        Device
        |> allow(self(), conn.owner)
        |> expect(:delete_interface_values, fn ^realm_name, ^device_id, ^interface_name, i_path ->
          full_path = "/" <> i_path
          assert full_path == path
          :ok
        end)

        conn = delete(conn, request_path)
        assert response(conn, 204)
      end
    end

    property "reading published data is consistent", context do
      %{realm_name: realm_name, interfaces: interfaces, device: device, auth_conn: conn} = context
      valid_interfaces_for_update = interfaces |> Enum.filter(&(&1.ownership == :server))

      check all interface_to_update <- member_of(valid_interfaces_for_update),
                mapping_update <- valid_mapping_update_for(interface_to_update) do
        request_path =
          interface_values_path(
            conn,
            :update,
            realm_name,
            device.encoded_id,
            interface_to_update.name,
            path_tokens(mapping_update.path)
          )

        update_value = mapping_update.value
        path_tokens = path_tokens(mapping_update.path)
        expected_token = [realm_name, device.encoded_id, interface_to_update.name | path_tokens]

        expected_published_value =
          expected_published_value!(mapping_update.value_type, update_value)

        expected_qos = expected_qos_for!(mapping_update)

        expected_read_value = expected_read_value!(mapping_update.value_type, update_value)

        publish_result_ok(interface_to_update, mapping_update, fn args ->
          assert %{payload: payload, topic_tokens: topic_tokens, qos: qos} = args
          assert topic_tokens == expected_token
          assert qos == expected_qos
          assert {:ok, %{"v" => ^expected_published_value}} = Cyanide.decode(payload)
        end)

        conn = post(conn, request_path, %{"data" => mapping_update.value})

        assert json_response(conn, 200)["data"] == mapping_update.value

        request_path =
          interface_values_path(
            conn,
            :show,
            realm_name,
            device.encoded_id,
            interface_to_update.name,
            path_tokens(mapping_update.path)
          )

        conn = get(conn, request_path)

        assert valid_result?(
                 json_response(conn, 200) |> get_in(["data" | path_tokens]),
                 interface_to_update,
                 expected_read_value
               )
      end
    end

    test "accepts and understands `keep_milliseconds` optional parameter", context do
      %{
        realm_name: realm_name,
        explicit_timestamp_interfaces: interfaces,
        device: device,
        auth_conn: conn
      } = context

      interface =
        interfaces
        |> Enum.random()

      mapping_update =
        interface
        |> valid_mapping_update_for()
        |> Enum.at(0)

      path = path_tokens(mapping_update.path)

      request_path =
        interface_values_path(
          conn,
          :update,
          realm_name,
          device.encoded_id,
          interface.name,
          path
        )

      publish_result_ok(interface, mapping_update, fn _ -> :ok end)

      expected_time = DateTime.utc_now(:millisecond)

      DateTime
      |> allow(conn.owner, self())
      |> stub(:utc_now, fn -> expected_time end)

      conn = post(conn, request_path, %{"data" => mapping_update.value})

      request_path =
        interface_values_path(
          conn,
          :show,
          realm_name,
          device.encoded_id,
          interface.name,
          path,
          %{"keep_milliseconds" => true}
        )

      conn = get(conn, request_path)

      response = json_response(conn, 200)

      %{"data" => data} = response
      timestamps = extract_timestamps(data)

      expected_time = DateTime.to_unix(expected_time, :millisecond)

      assert expected_time in timestamps
    end

    test "does not retrieve millisecond timestamp if `keep_milliseconds` is not set", context do
      %{
        realm_name: realm_name,
        explicit_timestamp_interfaces: interfaces,
        device: device,
        auth_conn: conn
      } = context

      interface =
        interfaces
        |> Enum.random()

      mapping_update =
        interface
        |> valid_mapping_update_for()
        |> Enum.at(0)

      path = path_tokens(mapping_update.path)

      request_path =
        interface_values_path(
          conn,
          :update,
          realm_name,
          device.encoded_id,
          interface.name,
          path
        )

      publish_result_ok(interface, mapping_update, fn _ -> :ok end)

      expected_time = DateTime.utc_now()

      DateTime
      |> allow(conn.owner, self())
      |> stub(:utc_now, fn -> expected_time end)

      conn = post(conn, request_path, %{"data" => mapping_update.value})

      request_path =
        interface_values_path(
          conn,
          :show,
          realm_name,
          device.encoded_id,
          interface.name,
          path,
          %{"keep_milliseconds" => false}
        )

      conn = get(conn, request_path)

      %{"data" => data} = json_response(conn, 200)
      timestamps = extract_timestamps(data)

      expected_time =
        expected_time
        |> DateTime.truncate(:millisecond)
        |> DateTime.to_iso8601()

      assert expected_time in timestamps
    end
  end

  def extract_timestamps(data),
    do: Enum.map(data, &Map.fetch!(&1, "timestamp"))

  property "deletes data if `allow_unset` is true", context do
    %{realm_name: realm_name, interfaces: interfaces, device: device, auth_conn: conn} = context

    valid_interfaces_to_unset =
      interfaces
      |> Enum.filter(fn interface ->
        allow_unset? = Enum.any?(interface.mappings, & &1.allow_unset)

        server? = interface.ownership == :server
        property? = interface.type == :properties

        property? && server? && allow_unset?
      end)

    check all interface <- member_of(valid_interfaces_to_unset),
              mapping_to_unset <-
                member_of(interface.mappings |> Enum.filter(& &1.allow_unset)),
              path <- path_from_endpoint(mapping_to_unset.endpoint) do
      if mapping_to_unset.allow_unset do
        path_tokens = path_tokens(path)
        expected_token = [realm_name, device.encoded_id, interface.name | path_tokens]

        publish_result_ok(interface, mapping_to_unset, fn args ->
          assert %{payload: payload, topic_tokens: topic_tokens, qos: qos} = args
          assert topic_tokens == expected_token
          assert qos == 2
          assert payload == ""
        end)
      end

      request_path =
        interface_values_path(
          conn,
          :delete,
          realm_name,
          device.encoded_id,
          interface.name,
          path_tokens(path)
        )

      conn = delete(conn, request_path)

      assert response(conn, 204)

      request_path =
        interface_values_path(
          conn,
          :show,
          realm_name,
          device.encoded_id,
          interface.name,
          path_tokens(path)
        )

      conn = get(conn, request_path)

      refute conn |> json_response(200) |> get_in(["data" | path_tokens(path)])
    end
  end

  property "forbids deletion if `allow_unset` is false", context do
    %{realm_name: realm_name, interfaces: interfaces, device: device, auth_conn: conn} = context

    valid_interfaces_to_unset =
      interfaces
      |> Enum.filter(fn interface ->
        allow_unset? = Enum.any?(interface.mappings, &(!&1.allow_unset))

        server? = interface.ownership == :server
        property? = interface.type == :properties

        property? && server? && allow_unset?
      end)

    check all interface <- member_of(valid_interfaces_to_unset),
              mapping_to_unset <-
                member_of(interface.mappings |> Enum.filter(&(!&1.allow_unset))),
              path <- path_from_endpoint(mapping_to_unset.endpoint) do
      if mapping_to_unset.allow_unset do
        path_tokens = path_tokens(path)
        expected_token = [realm_name, device.encoded_id, interface.name | path_tokens]

        publish_result_ok(interface, mapping_to_unset, fn args ->
          assert %{payload: payload, topic_tokens: topic_tokens, qos: qos} = args
          assert topic_tokens == expected_token
          assert qos == 2
          assert payload == ""
        end)
      end

      request_path =
        interface_values_path(
          conn,
          :delete,
          realm_name,
          device.encoded_id,
          interface.name,
          path_tokens(path)
        )

      conn = delete(conn, request_path)

      assert response(conn, 422)
    end
  end

  defp path_tokens(path) do
    String.split(path, "/", trim: true)
  end

  defp expected_qos_for!(mapping_update) do
    case mapping_update.reliability do
      :unreliable -> 0
      :guaranteed -> 1
      :unique -> 2
    end
  end
end
