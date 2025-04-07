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

  defp changes_from_struct(interface) do
    %Interface{
      name: name,
      major_version: major_version,
      minor_version: minor_version,
      mappings: mappings
    } = interface

    mappings = Enum.map(mappings, &Map.from_struct/1)

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
