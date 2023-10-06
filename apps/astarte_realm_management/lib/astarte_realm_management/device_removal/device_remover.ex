#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagement.DeviceRemoval.DeviceRemover do
  @moduledoc """
  This module handles data deletion for a device using a Task.
  The Task may fail at any time, notably if the database is not
  available.
  See Astarte.RealmManagement.DeviceRemoval.Scheduler for handling failures.
  """

  use Task
  require Logger
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.CQLUtils
  alias Astarte.RealmManagement.Queries
  alias Astarte.Core.Device

  @spec run(%{:device_id => <<_::128>>, :realm_name => binary()}) :: :ok | no_return()
  def run(%{realm_name: realm_name, device_id: device_id}) do
    encoded_device_id = Device.encode_device_id(device_id)
    _ = Logger.info("Starting to remove device #{encoded_device_id}", tag: "device_delete_start")

    Queries.retrieve_individual_datastreams_keys!(realm_name, device_id)
    |> Enum.each(&delete_individual_datastreams_from_key!(realm_name, &1))

    Queries.retrieve_individual_properties_keys!(realm_name, device_id)
    |> Enum.each(&delete_individual_properties_from_key!(realm_name, &1))

    retrieve_object_datastream_keys!(realm_name, device_id)
    |> Enum.each(&delete_object_datastreams_from_key!(realm_name, &1))

    retrieve_aliases_for_device!(realm_name, device_id)
    |> Enum.each(&Queries.delete_alias_values!(realm_name, &1))

    Queries.retrieve_groups_keys!(realm_name, device_id)
    |> Enum.each(&delete_group_from_key!(realm_name, &1))

    Queries.retrieve_kv_store_entries!(realm_name, encoded_device_id)
    |> Enum.each(&delete_kv_store_entry!(realm_name, &1))

    Queries.delete_device!(realm_name, device_id)
    Queries.remove_device_from_deletion_in_progress!(realm_name, device_id)
    _ = Logger.info("Successfully removed device #{encoded_device_id}", tag: "device_delete_ok")
    :ok
  end

  defp delete_individual_datastreams_from_key!(realm_name, key) do
    %{
      device_id: device_id,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      path: path
    } = key

    Queries.delete_individual_datastream_values!(
      realm_name,
      device_id,
      interface_id,
      endpoint_id,
      path
    )
  end

  defp delete_individual_properties_from_key!(realm_name, key) do
    %{
      device_id: device_id,
      interface_id: interface_id
    } = key

    Queries.delete_individual_properties_values!(realm_name, device_id, interface_id)
  end

  defp check_interface_has_object_aggregation!(realm_name, {interface_name, interface_major}) do
    case Queries.retrieve_interface_descriptor!(realm_name, interface_name, interface_major) do
      %InterfaceDescriptor{aggregation: :object} -> true
      _ -> false
    end
  end

  defp object_interface_to_table_name({interface_name, interface_major}) do
    CQLUtils.interface_name_to_table_name(interface_name, interface_major)
  end

  defp retrieve_object_datastream_keys!(realm_name, device_id) do
    Queries.retrieve_device_introspection_map!(realm_name, device_id)
    |> Enum.filter(&check_interface_has_object_aggregation!(realm_name, &1))
    |> Enum.map(&object_interface_to_table_name/1)
    |> Enum.flat_map(&retrieve_object_datastream_table_keys!(realm_name, device_id, &1))
  end

  defp retrieve_object_datastream_table_keys!(realm_name, device_id, table_name) do
    Queries.retrieve_object_datastream_keys!(
      realm_name,
      device_id,
      table_name
    )
    |> Enum.map(&Map.put(&1, :table_name, table_name))
  end

  defp delete_object_datastreams_from_key!(realm_name, key) do
    %{
      device_id: device_id,
      path: path,
      table_name: table_name
    } = key

    Queries.delete_object_datastream_values!(realm_name, device_id, path, table_name)
  end

  defp retrieve_aliases_for_device!(realm_name, device_id) do
    Queries.retrieve_aliases!(realm_name, device_id)
    |> Enum.map(fn %{object_name: device_alias} -> device_alias end)
  end

  defp delete_group_from_key!(realm_name, key) do
    %{
      device_id: device_id,
      group_name: group_name,
      insertion_uuid: insertion_uuid
    } = key

    Queries.delete_group_values!(realm_name, device_id, group_name, insertion_uuid)
  end

  defp delete_kv_store_entry!(realm_name, entry) do
    %{
      group: group_name,
      key: key
    } = entry

    Queries.delete_kv_store_entry!(realm_name, group_name, key)
  end
end
