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
defmodule Astarte.DataAccess.Generators.Mapping do
  @moduledoc """
  This module provides generators for Astarte.DataAccess.Mapping.
  """
  use ExUnitProperties

  alias Astarte.Core.Mapping

  alias Astarte.DataAccess.Realms.Endpoint, as: MappingData

  @doc """
  Map the core generator/struct to a data_access one
  """
  @spec from_core(Mapping.t()) :: StreamData.t(MappingData.t())
  def from_core(data) when not is_struct(data, StreamData),
    do: data |> constant() |> from_core()

  @spec from_core(StreamData.t(Mapping.t())) :: StreamData.t(MappingData.t())
  def from_core(gen) do
    gen all(
          %Mapping{
            endpoint: endpoint,
            value_type: value_type,
            reliability: reliability,
            retention: retention,
            expiry: expiry,
            database_retention_policy: database_retention_policy,
            database_retention_ttl: database_retention_ttl,
            allow_unset: allow_unset,
            explicit_timestamp: explicit_timestamp,
            endpoint_id: endpoint_id,
            interface_id: interface_id,
            doc: doc,
            description: description
          } <- gen
        ) do
      %MappingData{
        endpoint: endpoint,
        value_type: value_type,
        reliability: reliability,
        retention: retention,
        expiry: expiry,
        database_retention_policy: database_retention_policy,
        database_retention_ttl: database_retention_ttl,
        allow_unset: allow_unset,
        explicit_timestamp: explicit_timestamp,
        endpoint_id: endpoint_id,
        interface_id: interface_id,
        doc: doc,
        description: description
      }
    end
  end
end
