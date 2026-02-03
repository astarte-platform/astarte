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

defmodule Astarte.RealmManagement.Interfaces.Core do
  @moduledoc """
  Core logic for Interface management. 

  This module coordinates the lifecycvle of Astarte Interfaces, including storage updates, schema migrations, and secure deletion of interface data and associated device references.
  """
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.RealmManagement.Interfaces.MappingUpdates
  alias Astarte.RealmManagement.Interfaces.Queries

  require Logger

  def maybe_run_async(function, opts) do
    case Keyword.get(opts, :async, false) do
      true ->
        Task.async(function)
        {:ok, :started}

      false ->
        function.()
    end
  end

  def update_interface(
        realm_name,
        interface_descriptor,
        %MappingUpdates{} = mapping_updates,
        automaton,
        descr,
        doc
      ) do
    name = interface_descriptor.name
    major = interface_descriptor.major_version

    _ =
      Logger.info("Updating interface.",
        interface: name,
        interface_major: major,
        tag: "update_interface_started"
      )

    %MappingUpdates{new: new_mappings, updated: updated_mappings} = mapping_updates
    all_changed_mappings = new_mappings ++ updated_mappings

    with :ok <- Queries.update_interface_storage(realm_name, interface_descriptor, new_mappings) do
      Queries.update_interface(
        realm_name,
        interface_descriptor,
        all_changed_mappings,
        automaton,
        descr,
        doc
      )
    end
  end

  def delete_interface(realm_name, name, major) do
    with {:ok, descriptor} <-
           InterfaceQueries.fetch_interface_descriptor(realm_name, name, major),
         :ok <- Queries.delete_interface_storage(realm_name, descriptor),
         :ok <- Queries.delete_devices_with_data_on_interface(realm_name, name) do
      _ =
        Logger.info("Interface deletion started.",
          interface: name,
          interface_major: major,
          tag: "delete_interface_started"
        )

      Queries.delete_interface(realm_name, name, major)
    end
  end
end
