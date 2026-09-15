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

defmodule Astarte.Core.Generators.Triggers.SimpleConfigs.DataTriggerConfigTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Interface
  import Astarte.Core.Generators.Triggers.SimpleConfigs.DataTriggerConfig
  import Astarte.Core.Generators.Triggers.SimpleConfigs.Scope

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger

  describe "triggers data_trigger_config generator" do
    property "generates valid data_trigger_config" do
      check all data_trigger_config <- data_trigger_config() do
        assert %DataTrigger{} = data_trigger_config

        assert data_trigger_config ==
                 data_trigger_config |> DataTrigger.encode() |> DataTrigger.decode()
      end
    end

    property "uses the generated interface consistently" do
      check all %Interface{
                  name: interface_name,
                  major_version: interface_major,
                  mappings: mappings
                } = interface <- interface(),
                %DataTrigger{
                  interface_name: trigger_interface_name,
                  interface_major: trigger_interface_major,
                  match_path: match_path,
                  data_trigger_type: data_trigger_type,
                  value_match_operator: value_match_operator,
                  known_value: known_value
                } <- data_trigger_config(interface: interface) do
        assert interface_name == trigger_interface_name
        assert interface_major == trigger_interface_major
        assert valid_match_path?(mappings, match_path)
        assert valid_trigger_condition?(interface, match_path, data_trigger_type)
        assert valid_known_value?(value_match_operator, known_value)
      end
    end

    property "generates the consistent any-interface configuration" do
      check all data_trigger_config <-
                  data_trigger_config(interface: constant(:any_interface)) do
        assert %DataTrigger{
                 interface_name: "*",
                 interface_major: 0,
                 match_path: "/*",
                 data_trigger_type: :INCOMING_DATA,
                 value_match_operator: :ANY,
                 known_value: nil
               } = data_trigger_config
      end
    end

    property "uses a bottom-up trigger scope" do
      check all scope <- trigger_scope(),
                data_trigger_config <- data_trigger_config(scope: scope) do
        %DataTrigger{device_id: device_id, group_name: group_name} = data_trigger_config

        assert device_id == Map.get(scope, :device_id)
        assert group_name == Map.get(scope, :group_name)
      end
    end
  end

  defp valid_match_path?(_mappings, "/*"), do: true

  defp valid_match_path?(mappings, match_path) do
    Enum.any?(mappings, fn %Mapping{endpoint: endpoint} ->
      endpoint == match_path
    end)
  end

  defp valid_trigger_condition?(%Interface{aggregation: :object}, "/*", :INCOMING_DATA),
    do: true

  defp valid_trigger_condition?(%Interface{type: :datastream}, _match_path, data_trigger_type),
    do: data_trigger_type in [:INCOMING_DATA, :PATH_CREATED, :VALUE_STORED]

  defp valid_trigger_condition?(%Interface{type: :properties}, "/*", data_trigger_type),
    do: data_trigger_type not in [:VALUE_CHANGE, :VALUE_CHANGE_APPLIED]

  defp valid_trigger_condition?(%Interface{type: :properties}, _match_path, _data_trigger_type),
    do: true

  defp valid_known_value?(:ANY, nil), do: true

  defp valid_known_value?(_value_match_operator, known_value) when is_binary(known_value),
    do: match?(%{"v" => _value}, Cyanide.decode!(known_value))

  defp valid_known_value?(_value_match_operator, _known_value), do: false
end
