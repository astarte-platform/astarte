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

defmodule Astarte.Adapters.Generators do
  @moduledoc false
  use ExUnitProperties

  alias Astarte.Adapters.ComplexStruct
  alias Astarte.Adapters.SimpleStruct

  defp gen_struct(target_struct) do
    gen all id <- positive_integer(),
            name <- string(:ascii) do
      struct!(target_struct, id: id, name: name)
    end
  end

  @doc false
  def populate_raw_data do
    %{
      a: gen_struct(ComplexStruct),
      b: gen_struct(SimpleStruct) |> list_of()
    }
    |> fixed_map()
  end

  @doc false
  def populate_tree_data do
    gen all children <- gen_struct(SimpleStruct) |> list_of(),
            %ComplexStruct{} = owner <- gen_struct(ComplexStruct) do
      %ComplexStruct{owner | children: children}
    end
  end
end
