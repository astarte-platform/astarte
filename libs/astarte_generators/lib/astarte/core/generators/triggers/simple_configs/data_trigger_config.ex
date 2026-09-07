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

defmodule Astarte.Core.Generators.Triggers.SimpleConfigs.DataTriggerConfig do
  @moduledoc """
  Generates valid Astarte data trigger configurations.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Interface
  import Astarte.Core.Generators.Mapping
  import Astarte.Core.Generators.Triggers.SimpleConfigs.Scope, only: [trigger_scope: 0]

  alias Astarte.Core.Triggers.SimpleTriggerConfig

  @data_trigger_conditions [
    "incoming_data",
    "value_change",
    "value_change_applied",
    "path_created",
    "path_removed",
    "value_stored"
  ]

  @data_trigger_operators [
    "*",
    "==",
    "!=",
    ">",
    ">=",
    "<",
    "<=",
    "contains",
    "not_contains"
  ]

  @doc """
  Generates a valid data trigger configuration.
  """
  @spec data_trigger_config() :: StreamData.t(SimpleTriggerConfig.t())
  @spec data_trigger_config(params :: keyword()) :: StreamData.t(SimpleTriggerConfig.t())
  def data_trigger_config(params \\ []) do
    params gen all scope <- trigger_scope(),
                   %{device_id: default_device_id, group_name: default_group_name} = scope,
                   device_id <- constant(default_device_id),
                   group_name <- constant(default_group_name),
                   interface <- data_trigger_interface(),
                   %{
                     interface_name: default_interface_name,
                     interface_major: default_interface_major
                   } = interface,
                   interface_name <- constant(default_interface_name),
                   interface_major <- constant(default_interface_major),
                   on <- data_trigger_condition(interface_name),
                   match_path <- data_trigger_path(interface_name),
                   value_match_operator <- data_trigger_operator(match_path),
                   known_value <- data_trigger_known_value(value_match_operator),
                   params: params do
      %SimpleTriggerConfig{
        type: "data_trigger",
        on: on,
        group_name: group_name,
        device_id: device_id,
        interface_name: interface_name,
        interface_major: interface_major,
        match_path: match_path,
        value_match_operator: value_match_operator,
        known_value: known_value
      }
    end
  end

  defp data_trigger_interface, do: one_of([any_interface(), specific_interface()])

  defp data_trigger_condition("*"), do: constant("incoming_data")
  defp data_trigger_condition(_interface_name), do: member_of(@data_trigger_conditions)

  defp data_trigger_path("*"), do: constant("/*")
  defp data_trigger_path(_interface_name), do: one_of([constant("/*"), endpoint()])

  defp data_trigger_operator("/*"), do: constant("*")
  defp data_trigger_operator(_match_path), do: member_of(@data_trigger_operators)

  defp data_trigger_known_value("*"), do: constant(nil)

  defp data_trigger_known_value(_operator) do
    one_of([
      integer(),
      float(),
      boolean(),
      string(:utf8, min_length: 1),
      list_of(one_of([integer(), float(), boolean(), string(:utf8)]), min_length: 1)
    ])
  end

  defp any_interface,
    do: fixed_map(%{interface_name: constant("*"), interface_major: constant(nil)})

  defp specific_interface,
    do: fixed_map(%{interface_name: interface_name(), interface_major: interface_major_version()})
end
