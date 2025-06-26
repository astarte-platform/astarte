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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.RealmManagement.InterfacesTest do
  alias Astarte.RealmManagement.Queries
  alias Astarte.RealmManagement.Engine

  use Astarte.RealmManagement.DataCase, async: true
  use ExUnitProperties

  describe "Test interface" do
    @describetag :interfaces

    @tag :creation
    property "is installed properly", %{realm: realm} do
      check all(interface <- Astarte.Core.Generators.Interface.interface()) do
        json_interface = Jason.encode!(interface)

        :ok = Engine.install_interface(realm, json_interface)

        {:ok, fetched_interface} =
          Queries.fetch_interface(realm, interface.name, interface.major_version)

        assert interface.name == fetched_interface.name
        assert interface.major_version == fetched_interface.major_version
        assert interface.minor_version == fetched_interface.minor_version
        assert interface.type == fetched_interface.type
        assert interface.ownership == fetched_interface.ownership
        assert interface.aggregation == fetched_interface.aggregation
        assert interface.description == fetched_interface.description

        fetched_mappings =
          fetched_interface.mappings
          |> Enum.map(&mapping_to_comparable_map/1)
          |> MapSet.new()

        interface_mappings =
          interface.mappings
          |> Enum.map(&mapping_to_comparable_map/1)
          |> MapSet.new()

        assert MapSet.equal?(fetched_mappings, interface_mappings)

        _ = Queries.delete_interface(realm, interface.name, interface.major_version)
      end
    end
  end

  # Drops virtual and incomparable elements
  defp mapping_to_comparable_map(mapping) do
    Map.from_struct(mapping)
    |> Map.drop([:endpoint_id])
    |> Map.drop([:interface_id])
    |> Map.drop([:path])
    |> Map.drop([:type])
    |> Map.replace_lazy(:doc, fn doc ->
      if is_empty?(doc), do: nil, else: doc
    end)
    |> Map.replace_lazy(:description, fn desc ->
      if is_empty?(desc), do: nil, else: desc
    end)
  end

  defp is_empty?(nil), do: true

  defp is_empty?(string) do
    String.replace(string, " ", "") == ""
  end
end
