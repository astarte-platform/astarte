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

defmodule Astarte.Core.Generators.InterfaceTest do
  @moduledoc """
  Tests for Astarte Interface generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Interface

  @moduletag :interface

  defp mapping_changes(:properties, mapping) do
    expiry = if mapping.expiry == 0, do: nil, else: mapping.expiry
    retention = if mapping.retention == :discard, do: nil, else: mapping.retention
    reliability = if mapping.reliability == :unreliable, do: nil, else: mapping.reliability

    database_retention_policy =
      if mapping.database_retention_policy == :no_ttl,
        do: nil,
        else: mapping.database_retention_policy

    explicit_timestamp =
      if mapping.explicit_timestamp == false, do: nil, else: mapping.explicit_timestamp

    nilified_params = %{
      expiry: expiry,
      retention: retention,
      reliability: reliability,
      database_retention_policy: database_retention_policy,
      explicit_timestamp: explicit_timestamp
    }

    mapping = Map.from_struct(mapping)
    {value_type, mapping} = Map.pop(mapping, :value_type)

    mapping
    |> Map.put(:type, value_type)
    |> Map.merge(nilified_params)
  end

  defp mapping_changes(:datastream, mapping) do
    allow_unset = if mapping.allow_unset == false, do: nil, else: mapping.allow_unset

    mapping = Map.from_struct(mapping)
    {value_type, mapping} = Map.pop(mapping, :value_type)

    mapping
    |> Map.put(:type, value_type)
    |> Map.put(:allow_unset, allow_unset)
  end

  defp changes_from_struct(interface) do
    %Interface{
      name: name,
      major_version: major_version,
      minor_version: minor_version,
      mappings: mappings
    } = interface

    mappings = Enum.map(mappings, &mapping_changes(interface.type, &1))

    changeset_params =
      %{
        interface_name: name,
        version_major: major_version,
        version_minor: minor_version,
        mappings: mappings
      }

    valid_params =
      Map.take(interface, [:type, :ownership, :aggregation, :description, :doc, :quality])

    Map.merge(changeset_params, valid_params)
  end

  defp validation_helper(interface) do
    changes = changes_from_struct(interface)

    %Interface{}
    |> Interface.changeset(changes)
  end

  defp validation_fixture(_context), do: {:ok, validate: &validation_helper/1}

  @doc false
  describe "interface generator" do
    @describetag :success
    @describetag :ut

    setup :validation_fixture

    property "validate interface using Changeset", %{validate: validate} do
      check all(
              interface <- InterfaceGenerator.interface(),
              changeset = validate.(interface)
            ) do
        assert changeset.valid?, "Invalid interface: #{inspect(changeset.errors)}"
      end
    end
  end
end
