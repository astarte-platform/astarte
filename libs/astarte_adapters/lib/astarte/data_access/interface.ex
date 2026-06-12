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

defmodule Astarte.DataAccess.Adapters.Interface do
  @moduledoc """
  Mapping to Astarte.DataAccess.Interface
  """
  use Astarte.Adapters

  import Astarte.DataAccess.Realms.Interface, only: [storage: 1, storage_type: 1]

  alias Astarte.Core.Interface, as: InterfaceCore

  transform from_core_interface_to_change do
    @source InterfaceCore.t()
    @returns %{interface: map(), endpoints: list(map())}
    keep :interface_id, :name, :major_version, :minor_version, :aggregation, :ownership, :type

    field :storage, &interface_storage/1
    field :storage_type, &interface_storage_type/1
    field :doc <- :doc, required: false
    field :description <- :description, required: false
    field :endpoints <- :mappings, &mappings/2

    post_process &post_process/1
  end

  transformp mapping do
    keep :interface_id,
         :endpoint,
         :value_type,
         :reliability,
         :retention,
         :expiry,
         :database_retention_policy,
         :allow_unset,
         :explicit_timestamp,
         :endpoint_id

    field :database_retention_ttl <- :database_retention_ttl, required: false
    field :doc <- :doc, required: false
    field :description <- :description, required: false
  end

  # TODO workaround to fix macro vs. dialyzer
  @dialyzer {:nowarn_function, {:interface_storage, 1}}
  defp interface_storage(source), do: storage(source)
  # TODO workaround to fix macro vs. dialyzer
  @dialyzer {:nowarn_function, {:interface_storage_type, 1}}
  defp interface_storage_type(source), do: storage_type(source)

  defp mappings(mappings, %InterfaceCore{interface_id: interface_id}),
    do:
      Enum.map(
        mappings,
        &mapping(Map.merge(&1, %{interface_id: interface_id}))
      )

  defp post_process(source) do
    {endpoints, interface} = Map.pop(source, :endpoints)
    %{interface: interface, endpoints: endpoints}
  end
end
