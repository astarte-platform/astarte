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
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.SimpleConfigs.DataTriggerConfig
  import Astarte.Core.Generators.Triggers.SimpleTriggerConfigTest.Support

  @params [
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

  describe "data trigger configuration generator" do
    property "generates valid configurations" do
      check all config <- data_trigger_config() do
        assert valid_config?(config)
      end
    end

    test "generates constrained combinations" do
      for params <- @params do
        assert params |> data_trigger_config() |> Enum.at(0) |> valid_config?()
      end
    end
  end
end
