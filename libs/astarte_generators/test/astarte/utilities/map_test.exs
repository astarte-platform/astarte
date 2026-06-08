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

defmodule Astarte.Utilities.MapTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Utilities.Map, as: MapUtilities

  @moduletag :map
  @moduletag :fans

  @doc false
  describe "map_clean/1 utility" do
    @describetag :success
    @describetag :ut

    property "clean generated" do
      check all original_map <-
                  map_of(
                    one_of([string(:alphanumeric), atom(:alphanumeric)]),
                    member_of([nil, 1, "hello"])
                  ),
                cleaned_map = MapUtilities.clean(original_map) do
        assert cleaned_map |> Map.values() |> Enum.all?(&(not is_nil(&1)))
      end
    end
  end
end
