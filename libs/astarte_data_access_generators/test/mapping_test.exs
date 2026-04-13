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

defmodule Astarte.DataAccess.Generators.MappingTest do
  @moduledoc """
  Tests for Astarte Mapping generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.DataAccess.Realms.Endpoint, as: MappingData

  alias Astarte.Core.Generators.Mapping, as: MappingGenerator
  alias Astarte.DataAccess.Generators.Mapping, as: MappingDataGenerator

  @moduletag :mapping

  @doc false
  describe "mapping from_core/1" do
    @describetag :success
    @describetag :ut

    property "using from_core (gen)" do
      gen_data = MappingGenerator.mapping() |> MappingDataGenerator.from_core()

      check all(mapping <- gen_data) do
        assert is_struct(mapping, MappingData)
      end
    end

    property "using from_core (struct)" do
      check all mapping <- MappingGenerator.mapping(),
                mapping_data <- MappingDataGenerator.from_core(mapping) do
        assert is_struct(mapping_data, MappingData)
      end
    end
  end
end
