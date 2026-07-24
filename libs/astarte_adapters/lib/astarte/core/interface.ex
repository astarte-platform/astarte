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

defmodule Astarte.Core.Adapters.Interface do
  @moduledoc """
  Trasformings from Astarte.Core.Interface
  """
  use Astarte.Adapters

  alias Astarte.Core.Interface

  transform from_core_interface_to_change do
    @source Interface.t()
    @returns map()

    keep :type, :ownership, :aggregation

    field :description <- :description, required: false
    field :doc <- :doc, required: false
    field :interface_name <- :name
    field :version_major <- :major_version
    field :version_minor <- :minor_version
    field :mappings <- :mappings, &mappings/2
  end

  transformp mapping do
    keep :endpoint,
         :type,
         :reliability,
         :retention,
         :expiry,
         :database_retention_policy,
         :allow_unset,
         :explicit_timestamp,
         :endpoint_id

    field :type <- :value_type

    field :database_retention_ttl <- :database_retention_ttl, required: false
    field :description <- :description, required: false
    field :doc <- :doc, required: false
  end

  defp mappings(mappings, %Interface{interface_id: interface_id}),
    do: Enum.map(mappings, &mapping(&1, interface_id))

  defp mapping(mapping, interface_id),
    do: mapping |> Map.merge(%{interface_id: interface_id}) |> mapping()
end
