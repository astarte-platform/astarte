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
defmodule Astarte.DataAccess.Generators.Interface do
  @moduledoc """
  This module provides generators for Astarte.DataAccess.Interface.
  """
  use ExUnitProperties

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Interface

  alias Astarte.Core.Generators.StorageType, as: StorageTypeGenerator

  alias Astarte.DataAccess.Realms.Interface, as: InterfaceData

  @doc """
  Map the core generator/struct to a data_access one
  """
  @spec from_core(Interface.t()) :: StreamData.t(InterfaceData.t())
  def from_core(data) when not is_struct(data, StreamData),
    do: data |> constant() |> from_core()

  @spec from_core(StreamData.t(Interface.t())) :: StreamData.t(InterfaceData.t())
  def from_core(gen) do
    gen all %Interface{
              interface_id: interface_id,
              name: name,
              major_version: major_version,
              minor_version: minor_version,
              type: type,
              ownership: ownership,
              aggregation: aggregation
            } = interface <- gen,
            storage_type <- StorageTypeGenerator.storage_type(interface) do
      storage =
        case storage_type do
          :multi_interface_individual_properties_dbtable ->
            "individual_properties"

          :multi_interface_individual_datastream_dbtable ->
            "individual_datastreams"

          :one_object_datastream_dbtable ->
            CQLUtils.interface_name_to_table_name(name, major_version)
        end

      %InterfaceData{
        interface_id: interface_id,
        name: name,
        major_version: major_version,
        minor_version: minor_version,
        aggregation: aggregation,
        ownership: ownership,
        type: type,
        storage: storage,
        storage_type: storage_type
      }
    end
  end
end
