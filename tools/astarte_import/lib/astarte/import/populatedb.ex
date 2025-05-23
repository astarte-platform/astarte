#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.Import.PopulateDB do
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Mappings
  alias Astarte.Import
  alias Astarte.Import.PopulateDB.Queries
  require Logger

  defmodule State do
    defstruct [
      :prepared_params,
      :interface_descriptor,
      :mapping,
      :mappings,
      :last_seen_reception_timestamp,
      :prepared_query,
      :value_columns,
      :value_type
    ]
  end

  def populate(realm, xml, continuation_fun \\ :undefined) do
    Logger.info("Import started.", realm: realm)

    nodes = Application.get_env(:cqerl, :cassandra_nodes)
    {host, port} = Enum.random(nodes)
    Logger.info("Connecting to #{host}:#{port} cassandra database.", realm: realm)

    {:ok, xandra_conn} = Xandra.start_link(nodes: ["#{host}:#{port}"])

    got_interface_fun = fn %Import.State{data: data} = state, interface_name, major, minor ->
      Logger.info("Importing data for #{interface_name} v#{major}.#{minor}.",
        realm: realm,
        device_id: state.device_id
      )

      {:ok, interface_desc} = Interface.fetch_interface_descriptor(realm, interface_name, major)
      {:ok, mappings} = Mappings.fetch_interface_mappings(realm, interface_desc.interface_id)

      %Import.State{
        state
        | data: %State{data | interface_descriptor: interface_desc, mappings: mappings}
      }
    end

    got_path_fun = fn
      %Import.State{
        device_id: device_id,
        data: %State{
          mappings: mappings,
          interface_descriptor: %InterfaceDescriptor{
            aggregation: :individual,
            interface_id: interface_id,
            automaton: automaton,
            storage: storage
          }
        }
      } = state,
      path ->
        {:ok, endpoint_id} = EndpointsAutomaton.resolve_path(path, automaton)

        mapping = Enum.find(mappings, fn mapping -> mapping.endpoint_id == endpoint_id end)
        %Mapping{value_type: value_type} = mapping

        db_column_name = CQLUtils.type_to_db_column_name(value_type)

        statement = """
        INSERT INTO #{realm}.#{storage}
        (
          value_timestamp, reception_timestamp, reception_timestamp_submillis, #{db_column_name},
          device_id, interface_id, endpoint_id, path
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """

        {:ok, prepared_query} = Xandra.prepare(xandra_conn, statement)

        {:ok, decoded_device_id} = Device.decode_device_id(device_id)

        prepared_params = [
          decoded_device_id,
          interface_id,
          endpoint_id,
          path
        ]

        %Import.State{
          state
          | data: %State{
              state.data
              | mapping: mapping,
                prepared_params: prepared_params,
                prepared_query: prepared_query,
                value_type: value_type
            }
        }

      %Import.State{
        device_id: device_id,
        data: %State{
          mappings: mappings,
          interface_descriptor: %InterfaceDescriptor{
            aggregation: :object,
            name: name,
            major_version: major_version,
            storage: storage
          }
        }
      } = state,
      path ->
        expected_types = build_expected_type_map(mappings)

        value_columns =
          Enum.map(mappings, fn %Mapping{endpoint: endpoint} ->
            endpoint_key_token =
              endpoint
              |> String.split("/")
              |> List.last()

            db_column = CQLUtils.endpoint_to_db_column_name(endpoint)

            {endpoint_key_token, db_column}
          end)
          |> Enum.sort(fn {key1, _}, {key2, _} -> key1 <= key2 end)

        columns_string =
          Enum.map(value_columns, fn {_, db_column} ->
            [db_column, ", "]
          end)
          |> :erlang.iolist_to_binary()

        [first_mapping | _] = mappings
        %Mapping{explicit_timestamp: explicit_timestamp} = first_mapping

        virtual_mapping = %Mapping{
          first_mapping
          | endpoint_id: CQLUtils.endpoint_id(name, major_version, "")
        }

        {value_timestamp_string, additional_columns} =
          if explicit_timestamp do
            {"value_timestamp, ", 1}
          else
            {"", 0}
          end

        statement = """
        INSERT INTO #{realm}.#{storage}
        (
          #{value_timestamp_string} reception_timestamp, reception_timestamp_submillis, #{columns_string}
          device_id, path
        )
        VALUES (?, ?, ?, ? #{String.duplicate(", ?", additional_columns + length(value_columns))})
        """

        {:ok, prepared_query} = Xandra.prepare(xandra_conn, statement)

        {:ok, decoded_device_id} = Device.decode_device_id(device_id)

        prepared_params = [
          decoded_device_id,
          path
        ]

        %Import.State{
          state
          | data: %State{
              state.data
              | mapping: virtual_mapping,
                prepared_params: prepared_params,
                prepared_query: prepared_query,
                value_columns: value_columns,
                value_type: expected_types
            }
        }
    end

    got_path_end_fun = fn state ->
      %Import.State{
        device_id: device_id,
        path: path,
        data: %State{
          interface_descriptor: interface_descriptor,
          mapping: mapping,
          last_seen_reception_timestamp: reception_timestamp
        }
      } = state

      dbclient = {xandra_conn, realm}

      {:ok, decoded_device_id} = Device.decode_device_id(device_id)

      Queries.insert_path(
        dbclient,
        decoded_device_id,
        interface_descriptor,
        mapping,
        path,
        reception_timestamp,
        reception_timestamp,
        []
      )

      %Import.State{state | data: %State{state.data | mapping: nil}, path: nil}
    end

    got_device_end = fn state ->
      %Import.State{
        device_id: device_id,
        introspection: introspection,
        old_introspection: old_introspection,
        first_registration: first_registration,
        credentials_secret: credentials_secret,
        cert_serial: cert_serial,
        cert_aki: cert_aki,
        first_credentials_request: first_credentials_request,
        last_connection: last_connection,
        last_disconnection: last_disconnection,
        pending_empty_cache: pending_empty_cache,
        total_received_msgs: total_received_msgs,
        total_received_bytes: total_received_bytes,
        last_credentials_request_ip: last_credentials_request_ip,
        last_seen_ip: last_seen_ip
      } = state

      {:ok, decoded_device_id} = Device.decode_device_id(device_id)

      {introspection_major, introspection_minor} =
        Enum.reduce(introspection, {%{}, %{}}, fn item, acc ->
          {interface, {major, minor}} = item
          {introspection_major, introspection_minor} = acc

          {Map.put(introspection_major, interface, major),
           Map.put(introspection_minor, interface, minor)}
        end)

      dbclient = {xandra_conn, realm}

      Queries.do_register_device(
        dbclient,
        decoded_device_id,
        credentials_secret,
        first_registration
      )

      Queries.update_device_after_credentials_request(
        dbclient,
        decoded_device_id,
        %{serial: cert_serial, aki: cert_aki},
        last_credentials_request_ip,
        first_credentials_request
      )

      Queries.update_device_introspection(
        dbclient,
        decoded_device_id,
        introspection_major,
        introspection_minor
      )

      Queries.add_old_interfaces(dbclient, decoded_device_id, old_introspection)

      Queries.set_device_connected(dbclient, decoded_device_id, last_connection, last_seen_ip)

      Queries.set_device_disconnected(
        dbclient,
        decoded_device_id,
        last_disconnection,
        total_received_msgs,
        total_received_bytes
      )

      Queries.set_pending_empty_cache(dbclient, decoded_device_id, pending_empty_cache)

      state
    end

    got_end_of_value_fun = fn state, chars ->
      %Import.State{
        reception_timestamp: reception_timestamp,
        data: data
      } = state

      %State{
        prepared_params: prepared_params,
        prepared_query: prepared_query,
        value_type: value_type
      } = data

      reception_submillis = rem(DateTime.to_unix(reception_timestamp, :microsecond), 100)
      {:ok, native_value} = to_native_type(chars, value_type)

      params = [
        reception_timestamp,
        reception_timestamp,
        reception_submillis,
        native_value | prepared_params
      ]

      {:ok, %Xandra.Void{}} = Xandra.execute(xandra_conn, prepared_query, params)

      %Import.State{
        state
        | data: %State{data | last_seen_reception_timestamp: reception_timestamp}
      }
    end

    got_end_of_object_fun = fn state, object ->
      %Import.State{
        reception_timestamp: reception_timestamp,
        data: data
      } = state

      %State{
        mappings: mappings,
        prepared_params: prepared_params,
        prepared_query: prepared_query,
        value_columns: value_columns,
        value_type: expected_types
      } = data

      reception_submillis = rem(DateTime.to_unix(reception_timestamp, :microsecond), 100)
      {:ok, native_value} = to_native_type(object, expected_types)

      db_value =
        Enum.map(value_columns, fn {endpoint_key_token, _db_column} ->
          Map.get(native_value, endpoint_key_token)
        end)

      params = [reception_timestamp, reception_submillis | db_value] ++ prepared_params

      [%Mapping{explicit_timestamp: explicit_timestamp} | _] = mappings

      params =
        if explicit_timestamp do
          [reception_timestamp | params]
        else
          params
        end

      {:ok, %Xandra.Void{}} = Xandra.execute(xandra_conn, prepared_query, params)

      %Import.State{
        state
        | data: %State{data | last_seen_reception_timestamp: reception_timestamp}
      }
    end

    got_end_of_property_fun = fn state, chars ->
      %Import.State{
        device_id: device_id,
        path: path,
        data: %State{
          interface_descriptor: interface_descriptor,
          mappings: mappings
        }
      } = state

      %InterfaceDescriptor{
        automaton: automaton
      } = interface_descriptor

      {:ok, endpoint_id} = EndpointsAutomaton.resolve_path(path, automaton)

      mapping = Enum.find(mappings, fn mapping -> mapping.endpoint_id == endpoint_id end)
      %Mapping{value_type: value_type} = mapping

      {:ok, native_value} = to_native_type(chars, value_type)

      {:ok, decoded_device_id} = Device.decode_device_id(device_id)

      Queries.insert_value_into_db(
        {xandra_conn, realm},
        decoded_device_id,
        interface_descriptor,
        mapping,
        path,
        native_value,
        nil,
        DateTime.utc_now(),
        []
      )

      state
    end

    Import.parse(xml,
      continuation_fun: continuation_fun,
      data: %State{},
      got_end_of_object_fun: got_end_of_object_fun,
      got_end_of_value_fun: got_end_of_value_fun,
      got_end_of_property_fun: got_end_of_property_fun,
      got_device_end_fun: got_device_end,
      got_interface_fun: got_interface_fun,
      got_path_fun: got_path_fun,
      got_path_end_fun: got_path_end_fun
    )

    Logger.info("Import finished.", realm: realm)
  end

  defp to_native_type(value_chars, :double) do
    with float_string = to_string(value_chars),
         {value, ""} <- Float.parse(float_string) do
      {:ok, value}
    else
      _any ->
        {:error, :invalid_value}
    end
  end

  defp to_native_type(value_chars, :integer) do
    with integer_string = to_string(value_chars),
         {value, ""} when value >= -2_147_483_648 and value <= 2_147_483_647 <-
           Integer.parse(integer_string) do
      {:ok, value}
    else
      _any ->
        {:error, :invalid_value}
    end
  end

  defp to_native_type(value_chars, :boolean) do
    case value_chars do
      'true' -> {:ok, true}
      'false' -> {:ok, false}
      _any -> {:error, :invalid_value}
    end
  end

  defp to_native_type(value_chars, :longinteger) do
    with integer_string = to_string(value_chars),
         {value, ""}
         when value >= -9_223_372_036_854_775_808 and value <= 9_223_372_036_854_775_807 <-
           Integer.parse(integer_string) do
      {:ok, value}
    else
      _any ->
        {:error, :invalid_value}
    end
  end

  defp to_native_type(value_chars, :string) do
    with string = to_string(value_chars),
         true <- String.valid?(string) do
      {:ok, string}
    else
      _any ->
        {:error, :invalid_value}
    end
  end

  defp to_native_type(value_chars, :binaryblob) do
    with base64 = to_string(value_chars),
         {:ok, binary_blob} <- Base.decode64(base64) do
      {:ok, binary_blob}
    else
      _any ->
        {:error, :invalid_value}
    end
  end

  defp to_native_type(value_chars, :datetime) do
    with datestring = to_string(value_chars),
         {:ok, datetime, 0} <- DateTime.from_iso8601(datestring) do
      {:ok, datetime}
    else
      _any ->
        {:error, :invalid_value}
    end
  end

  defp to_native_type(value_chars, :doublearray) do
    value =
      Enum.map(value_chars, fn element ->
        {:ok, value} = to_native_type(element, :double)
        value
      end)

    {:ok, value}
  end

  defp to_native_type(value_chars, :integerarray) do
    value =
      Enum.map(value_chars, fn element ->
        {:ok, value} = to_native_type(element, :integer)
        value
      end)

    {:ok, value}
  end

  defp to_native_type(value_chars, :booleanarray) do
    value =
      Enum.map(value_chars, fn element ->
        {:ok, value} = to_native_type(element, :boolean)
        value
      end)

    {:ok, value}
  end

  defp to_native_type(value_chars, :longintegerarray) do
    value =
      Enum.map(value_chars, fn element ->
        {:ok, value} = to_native_type(element, :longinteger)
        value
      end)

    {:ok, value}
  end

  defp to_native_type(value_chars, :stringarray) do
    value =
      Enum.map(value_chars, fn element ->
        {:ok, value} = to_native_type(element, :string)
        value
      end)

    {:ok, value}
  end

  defp to_native_type(value_chars, :datetimearray) do
    value =
      Enum.map(value_chars, fn element ->
        {:ok, value} = to_native_type(element, :datetime)
        value
      end)

    {:ok, value}
  end

  defp to_native_type(value_chars, :binaryblobarray) do
    value =
      Enum.map(value_chars, fn element ->
        {:ok, value} = to_native_type(element, :binaryblob)
        value
      end)

    {:ok, value}
  end

  defp to_native_type(values, expected_types) when is_map(values) and is_map(expected_types) do
    obj =
      Enum.reduce(values, %{}, fn {"/" <> key, value}, acc ->
        value_type = Map.fetch!(expected_types, key)

        {:ok, native_type} = to_native_type(value, value_type)
        Map.put(acc, key, native_type)
      end)

    {:ok, obj}
  end

  defp build_expected_type_map(mappings) do
    Enum.reduce(mappings, %{}, fn %Mapping{value_type: value_type, endpoint: endpoint}, acc ->
      endpoint_key_token =
        endpoint
        |> String.split("/")
        |> List.last()

      Map.put(acc, endpoint_key_token, value_type)
    end)
  end
end
