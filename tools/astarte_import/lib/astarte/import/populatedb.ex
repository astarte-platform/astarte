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
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Mappings
  alias Astarte.Import

  defmodule State do
    defstruct [
      :prepared_params,
      :interface_descriptor,
      :mappings,
      :prepared_query,
      :value_type
    ]
  end

  def populate(realm, xml) do
    {:ok, conn} = Database.connect(realm)
    nodes = Application.get_env(:cqerl, :cassandra_nodes)
    {host, port} = Enum.random(nodes)
    {:ok, xandra_conn} = Xandra.start_link(nodes: ["#{host}:#{port}"])

    got_interface_fun = fn %Import.State{data: data} = state, interface_name, major, _minor ->
      {:ok, interface_desc} = Interface.fetch_interface_descriptor(conn, interface_name, major)
      {:ok, mappings} = Mappings.fetch_interface_mappings(conn, interface_desc.interface_id)

      %Import.State{
        state
        | data: %State{data | interface_descriptor: interface_desc, mappings: mappings}
      }
    end

    got_path_fun = fn %Import.State{data: data} = state, path ->
      %Import.State{
        device_id: device_id,
        data: %State{
          mappings: mappings,
          interface_descriptor: %InterfaceDescriptor{
            interface_id: interface_id,
            automaton: automaton,
            storage: storage
          }
        }
      } = state

      {:ok, endpoint_id} = EndpointsAutomaton.resolve_path(path, automaton)

      %Mapping{value_type: value_type} =
        Enum.find(mappings, fn mapping -> mapping.endpoint_id == endpoint_id end)

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
            data
            | prepared_params: prepared_params,
              prepared_query: prepared_query,
              value_type: value_type
          }
      }
    end

    fun = fn state, chars ->
      %Import.State{
        timestamp: timestamp,
        data: %State{
          prepared_params: prepared_params,
          prepared_query: prepared_query,
          value_type: value_type
        }
      } = state

      native_value = to_native_type(chars, value_type)
      params = [timestamp, timestamp, 0, native_value | prepared_params]

      {:ok, %Xandra.Void{}} = Xandra.execute(xandra_conn, prepared_query, params)

      state
    end

    Import.parse(xml,
      data: %State{},
      got_data_fun: fun,
      got_interface_fun: got_interface_fun,
      got_path_fun: got_path_fun
    )
  end

  defp to_native_type(value_chars, :double) do
    with float_string = to_string(value_chars),
         {value, ""} <- Float.parse(float_string) do
      value
    end
  end
end
