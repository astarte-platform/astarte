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

defmodule Astarte.Core.Generators.MappingTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping, as: MappingGenerator
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  @moduletag :core
  @moduletag :mapping

  @doc false
  describe "mapping generator" do
    @describetag :success
    @describetag :ut

    defp gen_mapping_changes(interface_type),
      do:
        MappingGenerator.mapping(interface_type: interface_type)
        |> MappingGenerator.to_changes()

    property "generates valid mapping" do
      check all %Interface{
                  name: interface_name,
                  major_version: interface_major,
                  interface_id: interface_id,
                  type: interface_type
                } <- InterfaceGenerator.interface(),
                changes <- gen_mapping_changes(interface_type),
                opts = [
                  interface_name: interface_name,
                  interface_major: interface_major,
                  interface_id: interface_id,
                  interface_type: interface_type
                ] do
        changeset = Mapping.changeset(%Mapping{}, changes, opts)
        assert changeset.valid?, "Invalid mapping: #{inspect(changeset, structs: false)}"
      end
    end

    @tag issue: 45
    property "type or value_type cannot be blank" do
      check all mapping <- MappingGenerator.mapping(interface_type: :datastream) do
        %Mapping{value_type: value_type, type: type} = mapping
        refute is_nil(value_type) or is_nil(type)
      end
    end

    @tag issue: 45
    property "json serialization/de does not make type null" do
      check all mapping <- MappingGenerator.mapping(),
                mapping_fields = mapping |> Jason.encode!() |> Jason.decode!(),
                %{"type" => type} = mapping_fields do
        refute is_nil(type)
      end
    end

    @tag issue: 49
    property "reliability is nil on Mapping" do
      check all %Mapping{reliability: reliability} <- MappingGenerator.mapping() do
        refute is_nil(reliability)
      end
    end
  end
end
