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

defmodule Astarte.Core.Generators.Triggers.SimpleConfigs.DeviceTriggerConfig do
  @moduledoc """
  Generates valid Astarte device trigger configurations.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Interface
  import Astarte.Core.Generators.Triggers.SimpleConfigs.Scope, only: [trigger_scope: 0]

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

  @interface_match_conditions ["interface_added", "interface_removed"]

  @doc """
  Generates a valid device trigger configuration.
  """
  @spec device_trigger_config() :: StreamData.t(SimpleTriggerConfig.t())
  @spec device_trigger_config(params :: keyword()) :: StreamData.t(SimpleTriggerConfig.t())
  def device_trigger_config(params \\ []) do
    params gen all scope <- trigger_scope(),
                   %{device_id: default_device_id, group_name: default_group_name} = scope,
                   device_id <- constant(default_device_id),
                   group_name <- constant(default_group_name),
                   on <- member_of(@device_trigger_conditions),
                   interface <- device_trigger_interface(on),
                   %{
                     interface_name: default_interface_name,
                     interface_major: default_interface_major
                   } = interface,
                   interface_name <- constant(default_interface_name),
                   interface_major <- constant(default_interface_major),
                   params: params do
      %SimpleTriggerConfig{
        type: "device_trigger",
        on: on,
        group_name: group_name,
        device_id: device_id,
        interface_name: interface_name,
        interface_major: interface_major
      }
    end
  end

  defp device_trigger_interface(on) when on in @interface_match_conditions,
    do: one_of([any_interface(), specific_interface()])

  defp device_trigger_interface("interface_minor_updated"), do: specific_interface()
  defp device_trigger_interface(_on), do: no_interface()

  defp any_interface,
    do: fixed_map(%{interface_name: constant("*"), interface_major: constant(nil)})

  defp specific_interface,
    do: fixed_map(%{interface_name: interface_name(), interface_major: interface_major_version()})

  defp no_interface,
    do: fixed_map(%{interface_name: constant(nil), interface_major: constant(nil)})
end
