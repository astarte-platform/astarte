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

defmodule Astarte.Core.Generators.Triggers.SimpleTriggerConfig do
  @moduledoc """
  Generates valid Astarte simple trigger configurations.
  """
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.SimpleConfigs.DataTriggerConfig
  import Astarte.Core.Generators.Triggers.SimpleConfigs.DeviceTriggerConfig

  alias Astarte.Core.Triggers.SimpleTriggerConfig

  @doc """
  Generates a valid data or device trigger configuration.

  The type parameter can select "data_trigger" or "device_trigger".
  """
  @spec simple_trigger_config() :: StreamData.t(SimpleTriggerConfig.t())
  @spec simple_trigger_config(params :: keyword()) :: StreamData.t(SimpleTriggerConfig.t())
  def simple_trigger_config(params \\ []) do
    type = Keyword.get(params, :type)
    params = Keyword.delete(params, :type)
    simple_trigger_config(type, params)
  end

  defp simple_trigger_config(nil, params),
    do: one_of([data_trigger_config(params), device_trigger_config(params)])

  defp simple_trigger_config("data_trigger", params), do: data_trigger_config(params)
  defp simple_trigger_config("device_trigger", params), do: device_trigger_config(params)
end
