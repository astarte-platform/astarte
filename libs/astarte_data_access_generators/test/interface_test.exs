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

defmodule Astarte.DataAccess.Generators.InterfaceTest do
  @moduledoc """
  Tests for Astarte Interface generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.CQLUtils

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  alias Astarte.DataAccess.Realms.Interface, as: InterfaceData

  alias Astarte.DataAccess.Generators.Interface, as: InterfaceDataGenerator

  @moduletag :interface

  defp retrieve_storage_type(%InterfaceData{type: :properties, aggregation: :individual}),
    do: :multi_interface_individual_properties_dbtable

  defp retrieve_storage_type(%InterfaceData{type: :datastream, aggregation: :individual}),
    do: :multi_interface_individual_datastream_dbtable

  defp retrieve_storage_type(%InterfaceData{type: :datastream, aggregation: :object}),
    do: :one_object_datastream_dbtable

  defp retrieve_storage_type(_), do: flunk("Inconsistent interface")

  defp retrieve_storage(%InterfaceData{type: :properties, aggregation: :individual}),
    do: "individual_properties"

  defp retrieve_storage(%InterfaceData{type: :datastream, aggregation: :individual}),
    do: "individual_datastreams"

  defp retrieve_storage(%InterfaceData{
         name: name,
         major_version: major_version,
         type: :datastream,
         aggregation: :object
       }),
       do: CQLUtils.interface_name_to_table_name(name, major_version)

  defp retrieve_storage(_), do: flunk("Inconsistent interface")

  @doc false
  describe "interface from_core/1" do
    @describetag :success
    @describetag :ut

    property "using from_core (gen)" do
      check all interface <- InterfaceGenerator.interface() |> InterfaceDataGenerator.from_core() do
        assert is_struct(interface, InterfaceData)
      end
    end

    property "using from_core (struct)" do
      check all interface <- InterfaceGenerator.interface(),
                interface_data <- InterfaceDataGenerator.from_core(interface) do
        assert is_struct(interface_data, InterfaceData)
      end
    end

    property "valid storage_type based on generated interface" do
      check all %InterfaceData{storage_type: storage_type} = interface <-
                  InterfaceGenerator.interface() |> InterfaceDataGenerator.from_core(),
                check_storage_type = retrieve_storage_type(interface) do
        assert storage_type == check_storage_type
      end
    end

    property "valid storage based on generated interface" do
      check all %InterfaceData{storage: storage} = interface <-
                  InterfaceGenerator.interface() |> InterfaceDataGenerator.from_core(),
                check_storage = retrieve_storage(interface) do
        assert storage == check_storage
      end
    end
  end
end
