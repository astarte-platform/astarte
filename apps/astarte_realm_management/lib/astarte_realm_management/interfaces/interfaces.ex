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

defmodule Astarte.RealmManagement.Interfaces do
  @moduledoc """
  Public API for Interface management within Astarte.

  It handles the complete lifecycle of Interfaces, including creation, updating, listing, and deletion.
  """
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Interface
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.DataAccess.Interface, as: DataAccessInterface
  alias Astarte.DataAccess.Mappings
  alias Astarte.RealmManagement.Interfaces.Core
  alias Astarte.RealmManagement.Interfaces.InterfacesListOptions
  alias Astarte.RealmManagement.Interfaces.MappingUpdates
  alias Astarte.RealmManagement.Interfaces.Queries

  require Logger

  def list_interfaces(realm_name, opts \\ %InterfacesListOptions{}) do
    case opts.detailed do
      true -> Queries.get_detailed_interfaces_list(realm_name)
      false -> Queries.get_interfaces_list(realm_name)
    end
  end

  def list_interface_major_versions(realm_name, id) do
    with {:ok, interface_versions_list} <-
           Queries.fetch_interface_versions_list(realm_name, id),
         interface_majors <- Enum.map(interface_versions_list, fn el -> el[:major_version] end) do
      {:ok, interface_majors}
    end
  end

  @doc delegate_to: {Queries, :fetch_interface, 3}
  defdelegate fetch_interface(realm, interface, major), to: Queries

  @doc """
  Installs a new interface in the specified realm.
  It performs several checks before proceeding with the installation:
  - Verifies that the mappings do not exceed the maximum storage retention allowed for the realm.
  - Checks if the interface can be installed (i.e., no existing interface with the same name and major version).
  - Checks for name collisions (i.e., no existing interface with the same normalized name
  - Verifies and builds the automaton for the mappings.

  If the `async` option is set to `true`, the installation will be performed asynchronously.

  ## Parameters
  - `realm_name`: The name of the realm where the interface will be installed.
  - `params`: A map containing the interface parameters, including name, major version, and mappings.
  - `opts`: Optional parameters. For now, it only supports `async` to determine if the installation should be performed asynchronously.

  ## Returns
  - `{:ok, interface}`: If the interface was successfully created and installed.
  - `{:error, reason}`: If there was an error during the creation or installation process.
  """
  def install_interface(realm_name, params, opts \\ []) do
    _ = Logger.info("Going to install a new interface.", tag: "install_interface")

    with {:ok, interface} <- build_interface(params),
         :ok <- verify_mappings_max_storage_retention(realm_name, interface),
         :ok <- can_install_interface?(realm_name, interface),
         {:ok, automaton} <- EndpointsAutomaton.build(interface.mappings) do
      _ =
        Logger.info("Installing interface.",
          interface: interface.name,
          interface_major: interface.major_version,
          tag: "install_interface_started"
        )

      if opts[:async],
        # TODO: add _ = Logger.metadata(realm: realm_name)
        do: Task.start(Queries, :install_interface, [realm_name, interface, automaton]),
        else: Queries.install_interface(realm_name, interface, automaton)

      {:ok, interface}
    end
  end

  defp build_interface(params) do
    interface =
      %Interface{}
      |> Interface.changeset(params)
      |> Ecto.Changeset.apply_action(:insert)

    with {:error, changeset} <- interface do
      _ =
        Logger.error("Invalid interface document.",
          reason: changeset.errors,
          tag: "invalid_interface_document"
        )

      {:error, changeset}
    end
  end

  defp can_install_interface?(realm_name, interface) do
    with :ok <- check_major_version(realm_name, interface) do
      check_name_collision(realm_name, interface)
    end
  end

  defp check_name_collision(realm_name, interface) do
    normalized_interface_name = normalize_interface_name(interface.name)

    with {:ok, names} <- Queries.fetch_all_interface_names(realm_name) do
      normalized_names = Enum.map(names, &normalize_interface_name/1)

      new_name? = Enum.all?(names, fn name -> name != interface.name end)

      collision? =
        Enum.any?(normalized_names, fn name -> name == normalized_interface_name end)

      case new_name? and collision? do
        true -> {:error, :interface_name_collision}
        false -> :ok
      end
    end
  end

  defp normalize_interface_name(interface_name) do
    String.replace(interface_name, "-", "")
    |> String.downcase()
  end

  defp check_major_version(realm_name, interface) do
    if Queries.interface_major_available?(
         realm_name,
         interface.name,
         interface.major_version
       ) do
      {:error, :already_installed_interface}
    else
      :ok
    end
  end

  defp verify_mappings_max_storage_retention(realm_name, interface) do
    with {:ok, max_retention} <- Queries.get_datastream_maximum_storage_retention(realm_name) do
      if mappings_retention_valid?(interface.mappings, max_retention) do
        :ok
      else
        {:error, :maximum_database_retention_exceeded}
      end
    end
  end

  defp mappings_retention_valid?(_mappings, 0), do: true

  defp mappings_retention_valid?(mappings, max_retention) do
    Enum.all?(mappings, fn %Mapping{database_retention_ttl: retention} ->
      retention <= max_retention
    end)
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

  defp check_name_matches(name_path, name_param) when name_path == name_param, do: :ok
  defp check_name_matches(_name_path, _name_param), do: {:error, :name_not_matching}
  defp check_major_matches(major_path, major_param) when major_path == major_param, do: :ok
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
           {:updated, true} <- {:updated, mapping_updated?(old_mapping, updated_mapping)} do
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

  defp mapping_updated?(mapping, upd_mapping) do
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
    _ =
      Logger.info("Going to delete interface.",
        tag: "delete_interface",
        interface: interface_name,
        interface_major: interface_major_version
      )

    with :ok <- check_interface_major_is_zero(interface_major_version),
         :ok <- check_interface_major_available_with_realm_check(realm_name, interface_name, 0),
         :ok <- check_interface_not_in_use_by_devices(realm_name, interface_name),
         :ok <- check_interface_not_in_use_by_triggers(realm_name, interface_name, 0) do
      interface_delete = fn ->
        Core.delete_interface(realm_name, interface_name, interface_major_version)
      end

      case Core.maybe_run_async(interface_delete, opts) do
        :ok -> :ok
        {:ok, :started} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp check_interface_major_is_zero(0 = _major), do: :ok
  defp check_interface_major_is_zero(_major), do: {:error, :forbidden}

  defp check_interface_major_available_with_realm_check(
         realm_name,
         interface_name,
         interface_major_version
       ) do
    check_interface_major_available(realm_name, interface_name, interface_major_version)
  rescue
    Xandra.Error ->
      # realm does not exist
      {:error, :interface_not_found}
  end

  defp check_interface_major_available(realm_name, interface_name, interface_major_version) do
    if Queries.interface_major_available?(
         realm_name,
         interface_name,
         interface_major_version
       ) do
      :ok
    else
      {:error, :interface_not_found}
    end
  end

  defp check_interface_not_in_use_by_devices(realm_name, interface_name) do
    case Queries.any_device_using_interface?(realm_name, interface_name) do
      false -> :ok
      true -> {:error, :cannot_delete_currently_used_interface}
    end
  end

  defp check_interface_not_in_use_by_triggers(realm_name, interface_name, interface_major_version) do
    interface_id = CQLUtils.interface_id(interface_name, interface_major_version)

    case Queries.has_interface_simple_triggers?(realm_name, interface_id) do
      false -> :ok
      true -> {:error, :cannot_delete_currently_used_interface}
    end
  end
end
