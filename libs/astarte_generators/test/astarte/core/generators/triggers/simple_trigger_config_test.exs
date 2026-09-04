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

defmodule Astarte.Core.Generators.Triggers.SimpleTriggerConfigTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.SimpleTriggerConfig

  alias Astarte.Core.Triggers.SimpleTriggerConfig

  @device_trigger_conditions [
    "device_connected",
    "device_disconnected",
    "device_empty_cache_received",
    "device_error",
    "incoming_introspection",
    "interface_added",
    "interface_removed",
    "interface_minor_updated",
    "device_registered",
    "device_deletion_started",
    "device_deletion_finished"
  ]

  @data_trigger_params [
    [interface_name: "*"],
    [
      interface_name: "com.Test.Interface",
      interface_major: 1,
      match_path: "/*"
    ],
    [
      interface_name: "com.Test.Interface",
      interface_major: 1,
      match_path: "/value",
      value_match_operator: "==",
      known_value: 1
    ]
  ]

  describe "simple trigger configuration generators" do
    property "generate valid configurations for every public entry point" do
      check all data_trigger <- data_trigger_config(),
                device_trigger <- device_trigger_config(),
                generic_trigger <- simple_trigger_config(),
                selected_data_trigger <- simple_trigger_config(type: "data_trigger"),
                selected_device_trigger <- simple_trigger_config(type: "device_trigger") do
        assert valid_config?(data_trigger) and
                 valid_config?(device_trigger) and
                 valid_config?(generic_trigger) and
                 valid_config?(selected_data_trigger) and
                 valid_config?(selected_device_trigger)
      end
    end

    test "generates every device trigger condition with valid interface matching" do
      for on <- @device_trigger_conditions do
        config = device_trigger_config(on: on) |> Enum.at(0)
        assert valid_config?(config)
      end
    end

    test "generates constrained data trigger combinations" do
      for params <- @data_trigger_params do
        config = data_trigger_config(params) |> Enum.at(0)
        assert valid_config?(config)
      end
    end
  end

  defp valid_config?(%SimpleTriggerConfig{} = config) do
    params =
      config |> Map.from_struct() |> Map.new(fn {key, value} -> {to_string(key), value} end)

    %Ecto.Changeset{valid?: valid?} =
      SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, params)

    valid?
  end
end
