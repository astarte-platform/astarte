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

defmodule Astarte.Core.Generators.Triggers.SimpleConfigs.SimpleTriggerConfig do
  @moduledoc """
  This module provides generators for Astarte Simple Trigger Config structs.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Triggers.SimpleConfigs.DataTriggerConfig
  import Astarte.Core.Generators.Triggers.SimpleConfigs.DeviceTriggerConfig

  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger

  @spec simple_trigger_config() :: StreamData.t(SimpleTriggerConfig.t())
  @spec simple_trigger_config(keyword :: keyword()) :: StreamData.t(SimpleTriggerConfig.t())
  def simple_trigger_config(params \\ []) do
    params gen all simple_trigger <- simple_trigger(),
                   params: params do
      from_simple_trigger(simple_trigger)
    end
  end

  defp simple_trigger do
    [
      {:data_trigger, data_trigger_config()},
      {:device_trigger, device_trigger_config()}
    ]
    |> one_of()
  end

  defp from_simple_trigger(simple_trigger) do
    %TaggedSimpleTrigger{
      simple_trigger_container: %SimpleTriggerContainer{simple_trigger: simple_trigger}
    }
    |> SimpleTriggerConfig.from_tagged_simple_trigger()
  end
end
