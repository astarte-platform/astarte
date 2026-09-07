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

defmodule Astarte.Core.Generators.InterfaceUpdateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Interface
  import Astarte.Core.Generators.InterfaceUpdate
  import Astarte.Core.Generators.InterfaceUpdateTest.Support
  import Astarte.Core.Generators.Mapping.ValueType, only: [value_type: 0]

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  describe "interface update generator" do
    property "generates represented updates for individual interfaces" do
      check all interface <- interface(aggregation: :individual),
                api_update <- valid_mapping_update_for(interface, :api),
                database_update <- valid_mapping_update_for(interface, :database) do
        assert valid_update?(interface, api_update, :api) and
                 valid_update?(interface, database_update, :database)
      end
    end

    property "generates represented updates for object interfaces" do
      check all interface <- interface(aggregation: :object),
                api_update <- valid_mapping_update_for(interface, :api),
                database_update <- valid_mapping_update_for(interface, :database) do
        assert valid_update?(interface, api_update, :api) and
                 valid_update?(interface, database_update, :database)
      end
    end

    property "generates standalone represented individual and object values" do
      check all value_type <- value_type(),
                api_value <- valid_update_value_for(value_type, :api),
                database_value <- valid_update_value_for(%{"value" => value_type}, :database) do
        assert represented?(value_type, api_value, :api) and
                 represented?(value_type, Map.fetch!(database_value, "value"), :database)
      end
    end

    test "force_allow_unset permits an empty database value" do
      interface = %Interface{
        aggregation: :individual,
        type: :properties,
        mappings: [
          %Mapping{endpoint: "/value", reliability: :unreliable, value_type: :string}
        ]
      }

      assert %{
               aggregation: :individual,
               reliability: :unique,
               value: "",
               value_type: :string
             } =
               interface
               |> valid_mapping_update_for(:database, force_allow_unset: true)
               |> StreamData.resize(0)
               |> Enum.at(0)
    end

    test "recognizes every represented value kind" do
      assert represented?(:binaryblob, Base.encode64("value"), :api) and
               represented?(:datetime, 0, :api) and
               represented?(:datetime, "2026-09-07T00:00:00Z", :api) and
               represented?(
                 :binaryblob,
                 %Cyanide.Binary{subtype: :generic, data: "value"},
                 :database
               ) and
               represented?(:datetime, 0, :database) and
               represented?(:datetime, ~U[2026-09-07 00:00:00Z], :database) and
               represented?(:stringarray, ["value"], :api) and
               represented?(:string, "value", :api)
    end
  end
end
