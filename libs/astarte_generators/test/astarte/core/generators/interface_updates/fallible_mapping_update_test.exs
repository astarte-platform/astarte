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

defmodule Astarte.Core.Generators.InterfaceUpdates.FallibleMappingUpdateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Interface
  import Astarte.Core.Generators.InterfaceUpdateTest.Support
  import Astarte.Core.Generators.InterfaceUpdates.FallibleMappingUpdate

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  @fallible_value_types [
    :integer,
    :longinteger,
    :string,
    :binaryblob,
    :doublearray,
    :integerarray,
    :booleanarray,
    :longintegerarray,
    :stringarray,
    :binaryblobarray,
    :datetimearray
  ]

  describe "fallible interface update generator" do
    property "generates represented updates containing fallible value types" do
      check all interface <- interface(aggregation: :object) |> filter(&fallible_interface?/1),
                api_update <- valid_fallible_mapping_update_for(interface, :api),
                database_update <- valid_fallible_mapping_update_for(interface, :database) do
        assert valid_update?(interface, api_update, :api) and
                 valid_update?(interface, database_update, :database) and
                 fallible_update?(api_update) and
                 fallible_update?(database_update)
      end
    end

    test "generates updates when every mapping is fallible" do
      interface = %Interface{
        aggregation: :object,
        type: :datastream,
        mappings: [
          %Mapping{endpoint: "/object/value", reliability: :guaranteed, value_type: :string}
        ]
      }

      assert %{
               aggregation: :object,
               reliability: :guaranteed,
               value_type: %{"value" => :string}
             } = valid_fallible_mapping_update_for(interface, :api) |> Enum.at(0)
    end
  end

  defp fallible_interface?(%Interface{mappings: mappings}),
    do:
      Enum.any?(mappings, fn %Mapping{value_type: value_type} ->
        value_type in @fallible_value_types
      end)

  defp fallible_update?(%{value_type: value_type}),
    do: Enum.any?(value_type, fn {_key, type} -> type in @fallible_value_types end)
end
