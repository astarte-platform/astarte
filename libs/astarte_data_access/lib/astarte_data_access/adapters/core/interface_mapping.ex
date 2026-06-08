#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.Adapters.Core.InterfaceMapping do
  @moduledoc """
  Mapping from Astarte.Core.Interface and Astarte.Core.Mapping
  """
  use Astarte.Adapters

  alias Ecto.Changeset

  alias Astarte.Core.Interface, as: InterfaceCore
  alias Astarte.Core.Mapping, as: MappingCore

  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.Interface

  transform from_core_interface do
    @source InterfaceCore.t()
    @returns %{interface: Changeset.t(), endpoints: list(Changeset.t())}
    field [:interface, :interface_id] <- :interface_id
    field [:interface, :name] <- :name
    field [:interface, :major_version] <- :major_version
    field [:interface, :minor_version] <- :minor_version
    field [:interface, :aggregation] <- :aggregation
    field [:interface, :ownership] <- :ownership
    field [:interface, :type] <- :type
    field [:interface, :storage], &Interface.storage/1
    field [:interface, :storage_type], &Interface.storage_type/1
    field [:interface, :doc] <- :doc, required: false
    field [:interface, :description] <- :description, required: false
    field :endpoints <- :mappings, &from_core_mappings/2
    post_process &from_core_post_process/1
  end

  transform from_core_mapping do
    @source %{interface_id: String.t(), mapping: MappingCore.t()}
    @returns Changeset.t()
    keep :interface_id
    field :endpoint <- [:mapping, :endpoint]
    field :value_type <- [:mapping, :value_type]
    field :reliability <- [:mapping, :reliability]
    field :retention <- [:mapping, :retention]
    field :expiry <- [:mapping, :expiry]
    field :database_retention_policy <- [:mapping, :database_retention_policy]
    field :database_retention_ttl <- [:mapping, :database_retention_ttl], required: false
    field :allow_unset <- [:mapping, :allow_unset]
    field :explicit_timestamp <- [:mapping, :explicit_timestamp]
    field :endpoint_id <- [:mapping, :endpoint_id]
    field :doc <- [:mapping, :doc], required: false
    field :description <- [:mapping, :description], required: false
    post_process &from_core_mapping_post_process/1
  end

  defp from_core_mappings(mappings, %InterfaceCore{interface_id: interface_id}),
    do: Enum.map(mappings, &from_core_mapping(%{interface_id: interface_id, mapping: &1}))

  defp from_core_post_process(%{interface: interface} = source),
    do: %{source | interface: Interface.changeset(%Interface{}, interface)}

  defp from_core_mapping_post_process(mapping), do: Endpoint.changeset(%Endpoint{}, mapping)
end
