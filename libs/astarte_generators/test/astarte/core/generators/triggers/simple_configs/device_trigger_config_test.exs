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

defmodule Astarte.Core.Generators.Triggers.SimpleConfigs.DeviceTriggerConfigTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.SimpleConfigs.DeviceTriggerConfig
  import Astarte.Core.Generators.Triggers.SimpleTriggerConfigTest.Support

  @conditions [
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

  describe "device trigger configuration generator" do
    property "generates valid configurations" do
      check all config <- device_trigger_config() do
        assert valid_config?(config)
      end
    end

    test "generates every condition with valid interface matching" do
      for on <- @conditions do
        assert [on: on] |> device_trigger_config() |> Enum.at(0) |> valid_config?()
      end
    end
  end
end
