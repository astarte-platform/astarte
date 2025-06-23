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

defmodule Astarte.RealmManagement.API.Interfaces do
  alias Astarte.RealmManagement.API.Interfaces.Queries
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Mapping
  alias Astarte.RealmManagement.API.Interfaces.MappingUpdates
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.RealmManagement.API.Interfaces.Core
  alias Astarte.DataAccess.Mappings
  alias Astarte.RealmManagement.API.RPC.RealmManagement
  alias Astarte.DataAccess.Interface, as: DataAccessInterface

  require Logger

  def list_interfaces(realm_name) do
    RealmManagement.get_interfaces_list(realm_name)
  end

  def list_interface_major_versions(realm_name, id) do
    with {:ok, interface_versions_list} <-
           RealmManagement.get_interface_versions_list(realm_name, id),
         interface_majors <- Enum.map(interface_versions_list, fn el -> el[:major_version] end) do
      {:ok, interface_majors}
    end
  end

  @doc delegate_to: {Queries, :fetch_interface, 3}
  defdelegate fetch_interface(realm, interface, major), to: Queries

  def create_interface(realm_name, params, opts \\ []) do
    changeset = Interface.changeset(%Interface{}, params)

    with {:ok, %Interface{} = interface} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, interface_source} <- Jason.encode(interface) do
      case RealmManagement.install_interface(realm_name, interface_source, opts) do
        :ok -> {:ok, interface}
        {:ok, :started} -> {:ok, interface}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def update_interface(realm_name, interface_name, major_version, params, opts \\ []) do
    changeset = Interface.changeset(%Interface{}, params)

    with {:ok, %Interface{} = interface} <- Ecto.Changeset.apply_action(changeset, :insert),
         :ok <- check_name_matches(interface_name, interface.name),
         :ok <- check_major_matches(major_version, interface.major_version),
         interface_descriptor = InterfaceDescriptor.from_interface(interface),
         {:ok, installed_interface} <-
           fetch_installed_interface_descriptor(realm_name, interface_name, major_version),
         :ok <- check_compatible_descriptor(installed_interface, interface_descriptor),
         :ok <- check_upgrade(installed_interface, interface_descriptor),
         {:ok, mapping_updates} <- extract_mapping_updates(realm_name, interface),
         {:ok, automaton} <- EndpointsAutomaton.build(interface.mappings) do
      interface_update =
        Map.merge(installed_interface, interface_descriptor, fn _k, old, new ->
          new || old
        end)

      interface_update = fn ->
        Core.update_interface(
          realm_name,
          interface_update,
          mapping_updates,
          automaton,
          interface.description,
          interface.doc
        )
      end

      case Core.maybe_run_async(interface_update, opts) do
        :ok -> :ok
        {:ok, :started} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp check_name_matches(name = _name_path, name = _name_param), do: :ok
  defp check_name_matches(_name_path, _name_param), do: {:error, :name_not_matching}
  defp check_major_matches(major = _major_path, major = _major_param), do: :ok
  defp check_major_matches(_major_path, _major_param), do: {:error, :major_version_not_matching}

  defp fetch_installed_interface_descriptor(realm_name, name, major) do
    case DataAccessInterface.fetch_interface_descriptor(realm_name, name, major) do
      {:ok, installed_descriptor} -> {:ok, installed_descriptor}
      {:error, :interface_not_found} -> {:error, :interface_major_version_does_not_exist}
    end
  end

  defp check_compatible_descriptor(installed_interface, update_interface) do
    installed =
      installed_interface
      |> Map.take([:name, :major_version, :type, :ownership, :aggregation, :interface_id])

    update =
      update_interface
      |> Map.take([:name, :major_version, :type, :ownership, :aggregation, :interface_id])

    if installed == update do
      :ok
    else
      Logger.debug("Incompatible change: #{inspect(update_interface)}.")
      {:error, :invalid_update}
    end
  end

  defp check_upgrade(installed, update) do
    installed = installed.minor_version
    update = update.minor_version

    case {installed, update} do
      {installed, update} when installed < update -> :ok
      {same_version, same_version} -> {:error, :minor_version_not_increased}
      {installed, update} when installed > update -> {:error, :downgrade_not_allowed}
    end
  end

  defp extract_mapping_updates(realm_name, interface) do
    with {:ok, existing_mappings_map} <-
           Mappings.fetch_interface_mappings_map(realm_name, interface.interface_id,
             include_docs: true
           ) do
      mappings_map = interface.mappings |> Map.new(&{&1.endpoint_id, &1})

      existing_endpoints = Map.keys(existing_mappings_map)
      {existing_mappings, new_mappings} = Map.split(mappings_map, existing_endpoints)

      with {:ok, changed_mappings} <-
             extract_changed_mappings(existing_mappings_map, existing_mappings) do
        mapping_updates = %MappingUpdates{
          new: Map.values(new_mappings),
          updated: Map.values(changed_mappings)
        }

        {:ok, mapping_updates}
      end
    end
  end

  defp extract_changed_mappings(old_mappings, changed_mappings) do
    Enum.reduce_while(old_mappings, {:ok, %{}}, fn {mapping_id, old_mapping}, {:ok, acc} ->
      with {:ok, updated_mapping} <- Map.fetch(changed_mappings, mapping_id),
           {:allowed, true} <- {:allowed, allowed_mapping_update?(old_mapping, updated_mapping)},
           {:updated, true} <- {:updated, is_mapping_updated?(old_mapping, updated_mapping)} do
        {:cont, {:ok, Map.put(acc, mapping_id, updated_mapping)}}
      else
        :error ->
          {:halt, {:error, :missing_endpoints}}

        {:allowed, false} ->
          {:halt, {:error, :incompatible_endpoint_change}}

        {:updated, false} ->
          {:cont, {:ok, acc}}
      end
    end)
  end

  defp allowed_mapping_update?(mapping, upd_mapping) do
    new_mapping = drop_mapping_negligible_fields(upd_mapping)
    old_mapping = drop_mapping_negligible_fields(mapping)

    new_mapping == old_mapping
  end

  defp is_mapping_updated?(mapping, upd_mapping) do
    mapping.explicit_timestamp != upd_mapping.explicit_timestamp or
      mapping.doc != upd_mapping.doc or
      mapping.description != upd_mapping.description or
      mapping.retention != upd_mapping.retention or
      mapping.expiry != upd_mapping.expiry
  end

  defp drop_mapping_negligible_fields(%Mapping{} = mapping) do
    %{
      mapping
      | doc: nil,
        description: nil,
        explicit_timestamp: false,
        retention: nil,
        expiry: nil
    }
  end

  def delete_interface(
        realm_name,
        interface_name,
        interface_major_version,
        opts \\ []
      ) do
    case RealmManagement.delete_interface(
           realm_name,
           interface_name,
           interface_major_version,
           opts
         ) do
      :ok -> :ok
      {:ok, :started} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
