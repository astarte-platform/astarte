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
#

defmodule Astarte.Export do
  alias Astarte.Export.FetchData
  alias Astarte.Export.XMLGenerate
  require Logger

  @moduledoc """
    This  module provide API functions to export realm device
    data in a xml format. This data can be used by astarte_import
    application utlity  to import into a new realm.
  """

  @doc """
    The export_realm_data/2 function required 2 arguments to export
    the realm data into XML format.
    the arguments are
    - realm-name -> This is a string format of input
    - file      -> file where to export the realm data.
    - options   -> options to export the realm data.
  """

  @spec export_realm_data(String.t(), String.t(), keyword()) ::
          :ok | {:error, :invalid_parameters} | {:error, any()}

  def export_realm_data(realm, file, opts \\ []) do
    file = Path.expand(file) |> Path.absname()

    with {:ok, fd} <- File.open(file, [:write]) do
      generate_xml(realm, fd, opts)
    end
  end

  defp generate_xml(realm, fd, opts \\ []) do
    Logger.info("Export started.", realm: realm, tag: "export_started")

    with {:ok, state} <- XMLGenerate.xml_write_default_header(fd),
         {:ok, state} <- XMLGenerate.xml_write_start_tag(fd, {"astarte", []}, state),
         {:ok, state} <- XMLGenerate.xml_write_start_tag(fd, {"devices", []}, state),
         {:ok, conn} <- FetchData.db_connection_identifier(),
         {:ok, state} <- process_devices(conn, realm, fd, state, opts),
         {:ok, state} <- XMLGenerate.xml_write_end_tag(fd, state),
         {:ok, _state} <- XMLGenerate.xml_write_end_tag(fd, state),
         :ok <- File.close(fd) do
      Logger.info("Export Completed.", realm: realm, tag: "export_completed")
      {:ok, :export_completed}
    else
      {:error, reason} ->
        File.close(fd)
        {:error, reason}
    end
  end

  defp process_devices(conn, realm, fd, state, opts \\ []) do
    tables_page_configs = Application.get_env(:xandra, :cassandra_table_page_sizes, [])
    page_size = Keyword.get(tables_page_configs, :device_table_page_size, 100)
    options = [page_size: page_size]
    process_devices(conn, realm, fd, state, options, opts)
  end

  defp process_devices(conn, realm, fd, state, options, opts) do
    with {:more_data, device_list, updated_options} <-
           FetchData.fetch_device_data(conn, realm, options, opts),
         {:ok, state} <- process_device_list(conn, realm, device_list, fd, state),
         {:ok, paging_state} when paging_state != nil <-
           Keyword.fetch(updated_options, :paging_state) do
      process_devices(conn, realm, fd, state, updated_options, opts)
    else
      {:ok, nil} -> {:ok, state}
      {:ok, :completed} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_device_list(_, _, [], _, state) do
    {:ok, state}
  end

  defp process_device_list(conn, realm, [h | t], fd, state) do
    with {:ok, state} <- do_process_device(conn, realm, h, fd, state) do
      process_device_list(conn, realm, t, fd, state)
    end
  end

  defp do_process_device(conn, realm, device_data, fd, state) do
    mapped_device_data = FetchData.process_device_data(device_data)
    device = mapped_device_data.device

    with {:ok, state} <- XMLGenerate.xml_write_start_tag(fd, {"device", device}, state),
         {:ok, state} <- construct_device_xml_tags(mapped_device_data, fd, state),
         {:ok, state} <- process_interfaces(conn, realm, device_data, fd, state),
         {:ok, state} <- XMLGenerate.xml_write_end_tag(fd, state) do
      {:ok, state}
    end
  end

  def process_interfaces(conn, realm, device_data, fd, state) do
    with {:ok, interfaces} <- FetchData.get_interface_details(conn, realm, device_data),
         {:ok, state} <- XMLGenerate.xml_write_start_tag(fd, {"interfaces", []}, state),
         {:ok, state} <- process_interface_list(conn, realm, interfaces, fd, state),
         {:ok, state} <- XMLGenerate.xml_write_end_tag(fd, state) do
      {:ok, state}
    end
  end

  defp process_interface_list(_, _, [], _, state) do
    {:ok, state}
  end

  defp process_interface_list(conn, realm, [h | t], fd, state) do
    with {:ok, state} <- do_process_interface(conn, realm, h, fd, state) do
      process_interface_list(conn, realm, t, fd, state)
    end
  end

  defp do_process_interface(conn, realm, %{type: :properties} = interface_info, fd, state) do
    %{
      attributes: attributes,
      mappings: mappings
    } = interface_info

    table_page_sizes = Application.get_env(:xandra, :cassandra_table_page_sizes, [])
    page_size = Keyword.get(table_page_sizes, :individual_properties, 1000)
    opts = [page_size: page_size]

    with {:ok, state} <- XMLGenerate.xml_write_start_tag(fd, {"interface", attributes}, state),
         {:ok, state} <-
           process_property_streams(conn, realm, mappings, interface_info, fd, state, opts),
         {:ok, state} <- XMLGenerate.xml_write_end_tag(fd, state) do
      {:ok, state}
    end
  end

  defp do_process_interface(conn, realm, %{type: :individual} = interface_info, fd, state) do
    %{
      attributes: attributes,
      mappings: mappings
    } = interface_info

    table_page_sizes = Application.get_env(:xandra, :cassandra_table_page_sizes, [])
    page_size = Keyword.get(table_page_sizes, :individual_datastreams, 1000)
    opts = [page_size: page_size]

    with {:ok, state} <- XMLGenerate.xml_write_start_tag(fd, {"interface", attributes}, state),
         {:ok, state} <-
           process_individual_streams(conn, realm, mappings, interface_info, fd, state, opts),
         {:ok, state} <- XMLGenerate.xml_write_end_tag(fd, state) do
      {:ok, state}
    end
  end

  defp do_process_interface(conn, realm, %{type: :object} = interface_info, fd, state) do
    %{
      attributes: attributes,
      mappings: mappings
    } = interface_info

    table_page_sizes = Application.get_env(:xandra, :cassandra_table_page_sizes, [])
    page_size = Keyword.get(table_page_sizes, :object_datastreams, 1000)
    opts = [page_size: page_size]

    with {:ok, state} <- XMLGenerate.xml_write_start_tag(fd, {"interface", attributes}, state),
         {:ok, state} <-
           process_object_streams(conn, realm, mappings, interface_info, fd, state, opts),
         {:ok, state} <- XMLGenerate.xml_write_end_tag(fd, state) do
      {:ok, state}
    end
  end

  defp process_object_streams(conn, realm, mappings, interface_info, fd, state, opts) do
    [h | _t] = mappings
    path = "" <> h.path

    sub_paths_info =
      Enum.reduce(mappings, [], fn mapping, acc1 ->
        path = mapping.endpoint
        [_, _, suffix] = String.split(path, "/")
        data_type = mapping.value_type
        [%{suffix_path: suffix, data_type: data_type} | acc1]
      end)

    updated_interface_info =
      Map.put(interface_info, :path, path)
      |> Map.put(:sub_path_info, sub_paths_info)

    with {:ok, state} <- XMLGenerate.xml_write_start_tag(fd, {"datastream", [path: path]}, state),
         {:ok, state} <-
           do_process_object_streams(conn, realm, updated_interface_info, fd, state, opts),
         {:ok, state} <- XMLGenerate.xml_write_end_tag(fd, state) do
      {:ok, state}
    end
  end

  defp process_individual_streams(_, _, [], _, _, state, _) do
    {:ok, state}
  end

  defp process_individual_streams(conn, realm, [h | t], interface_info, fd, state, opts) do
    with {:ok, state} <-
           XMLGenerate.xml_write_start_tag(fd, {"datastream", [path: h.path]}, state),
         {:ok, state} <-
           do_process_individual_streams(conn, realm, h, interface_info, fd, state, opts),
         {:ok, state} <- XMLGenerate.xml_write_end_tag(fd, state) do
      process_individual_streams(conn, realm, t, interface_info, fd, state, opts)
    end
  end

  defp process_property_streams(_, _, [], _, _, state, _) do
    {:ok, state}
  end

  defp process_property_streams(conn, realm, [h | t], interface_info, fd, state, opts) do
    with {:ok, state} <-
           do_process_property_streams(conn, realm, h, interface_info, fd, state, opts) do
      process_property_streams(conn, realm, t, interface_info, fd, state, opts)
    end
  end

  defp do_process_object_streams(conn, realm, interface_info, fd, state, opts) do
    with {:more_data, object_data, updated_options} <-
           FetchData.fetch_object_datastreams(conn, realm, interface_info, opts),
         {:ok, state} <- generate_object_stream_xml(fd, state, object_data),
         {:ok, paging_state} when paging_state != nil <-
           Keyword.fetch(updated_options, :paging_state) do
      do_process_object_streams(conn, realm, interface_info, fd, state, updated_options)
    else
      {:ok, nil} -> {:ok, state}
      {:ok, :completed} -> {:ok, state}
      {:error, reason} -> {:error, {reason, :failed_processing_object_stream}}
    end
  end

  defp do_process_individual_streams(conn, realm, mapping, interface_info, fd, state, opts) do
    with {:more_data, data, updated_opts} <-
           FetchData.fetch_individual_datastreams(conn, realm, mapping, interface_info, opts),
         {:ok, state} <- generate_individual_stream_xml(fd, state, data),
         {:ok, paging_state} when paging_state != nil <-
           Keyword.fetch(updated_opts, :paging_state) do
      do_process_individual_streams(conn, realm, mapping, interface_info, fd, state, updated_opts)
    else
      {:ok, nil} -> {:ok, state}
      {:ok, :completed} -> {:ok, state}
      {:error, reason} -> {:error, {reason, :failed_processing_individual_stream}}
    end
  end

  defp do_process_property_streams(conn, realm, mapping, interface_info, fd, state, opts) do
    with {:more_data, data, updated_opts} <-
           FetchData.fetch_individual_properties(conn, realm, mapping, interface_info, opts),
         {:ok, state} <- generate_property_stream_xml(fd, state, data),
         {:ok, paging_state} when paging_state != nil <-
           Keyword.fetch(updated_opts, :paging_state) do
      do_process_property_streams(conn, realm, mapping, interface_info, fd, state, updated_opts)
    else
      {:ok, nil} -> {:ok, state}
      {:ok, :completed} -> {:ok, state}
      {:error, reason} -> {:error, {reason, :failed_processing_property_streams}}
    end
  end

  defp generate_individual_stream_xml(_, state, []) do
    {:ok, state}
  end

  defp generate_individual_stream_xml(fd, state, [h | t]) do
    %{value: value, attributes: attributes} = h
    {:ok, state} = XMLGenerate.xml_write_full_element(fd, {"value", attributes, value}, state)
    generate_individual_stream_xml(fd, state, t)
  end

  defp generate_property_stream_xml(_, state, []) do
    {:ok, state}
  end

  defp generate_property_stream_xml(fd, state, [h | t]) do
    %{value: value, attributes: attributes} = h
    {:ok, state} = XMLGenerate.xml_write_full_element(fd, {"property", attributes, value}, state)
    generate_property_stream_xml(fd, state, t)
  end

  defp generate_object_stream_xml(_, state, []) do
    {:ok, state}
  end

  defp generate_object_stream_xml(fd, state, [h | t]) do
    %{attributes: attributes, value: value} = h
    {:ok, state} = XMLGenerate.xml_write_start_tag(fd, {"object", attributes}, state)
    {:ok, state} = generate_object_item_xml(fd, state, value)
    {:ok, state} = XMLGenerate.xml_write_end_tag(fd, state)
    generate_object_stream_xml(fd, state, t)
  end

  defp generate_object_item_xml(_, state, []) do
    {:ok, state}
  end

  defp generate_object_item_xml(fd, state, [h | t]) do
    %{attributes: attributes, value: value} = h
    {:ok, state} = XMLGenerate.xml_write_full_element(fd, {"item", attributes, value}, state)
    generate_object_item_xml(fd, state, t)
  end

  def construct_device_xml_tags(device_data, fd, state) do
    %{
      protocol: protocol,
      registration: registration,
      credentials: credentials,
      stats: stats
    } = device_data

    with {:ok, state} <-
           XMLGenerate.xml_write_empty_element(fd, {"protocol", protocol, []}, state),
         {:ok, state} <-
           XMLGenerate.xml_write_empty_element(fd, {"registration", registration, []}, state),
         {:ok, state} <-
           XMLGenerate.xml_write_empty_element(fd, {"credentials", credentials, []}, state),
         {:ok, state} <- XMLGenerate.xml_write_empty_element(fd, {"stats", stats, []}, state) do
      {:ok, state}
    end
  end
end
