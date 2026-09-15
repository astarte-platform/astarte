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

defmodule Astarte.Core.Generators.Triggers.SimpleConfigs.SimpleTriggerConfigTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.SimpleConfigs.DataTriggerConfig
  import Astarte.Core.Generators.Triggers.SimpleConfigs.DeviceTriggerConfig
  import Astarte.Core.Generators.Triggers.SimpleConfigs.SimpleTriggerConfig

  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger

  describe "triggers simple_trigger_config generator" do
    property "generates valid simple_trigger_config structs" do
      check all simple_trigger_config <- simple_trigger_config() do
        assert %SimpleTriggerConfig{type: type} = simple_trigger_config
        assert type in ["data_trigger", "device_trigger"]

        params =
          simple_trigger_config
          |> Map.from_struct()
          |> Map.new(fn {key, value} -> {to_string(key), value} end)

        assert %Ecto.Changeset{valid?: true} =
                 SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, params)
      end
    end

    property "uses a bottom-up data trigger configuration" do
      check all data_trigger <- data_trigger_config(),
                simple_trigger_config <-
                  simple_trigger_config(simple_trigger: constant({:data_trigger, data_trigger})) do
        assert from_simple_trigger({:data_trigger, data_trigger}) == simple_trigger_config
      end
    end

    property "uses a bottom-up device trigger configuration" do
      check all device_trigger <- device_trigger_config(),
                simple_trigger_config <-
                  simple_trigger_config(
                    simple_trigger: constant({:device_trigger, device_trigger})
                  ) do
        assert from_simple_trigger({:device_trigger, device_trigger}) == simple_trigger_config
      end
    end
  end

  defp from_simple_trigger(simple_trigger) do
    %TaggedSimpleTrigger{
      simple_trigger_container: %SimpleTriggerContainer{simple_trigger: simple_trigger}
    }
    |> SimpleTriggerConfig.from_tagged_simple_trigger()
  end
end
