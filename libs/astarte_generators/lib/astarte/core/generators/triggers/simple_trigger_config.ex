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

  The generators accept field overrides through the `params gen all` convention. The generic
  generator also accepts `type: "data_trigger"` or `type: "device_trigger"` to select a specific
  trigger family.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Device
  import Astarte.Core.Generators.Group
  import Astarte.Core.Generators.Interface
  import Astarte.Core.Generators.Mapping

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
  Generates a valid data or device trigger configuration.
  """
  @spec simple_trigger_config() :: StreamData.t(SimpleTriggerConfig.t())
  @spec simple_trigger_config(params :: keyword()) :: StreamData.t(SimpleTriggerConfig.t())
  def simple_trigger_config(params \\ []) do
    type = Keyword.get(params, :type)
    params = Keyword.delete(params, :type)
    simple_trigger_config(type, params)
  end

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

  defp simple_trigger_config(nil, params),
    do: one_of([data_trigger_config(params), device_trigger_config(params)])

  defp simple_trigger_config("data_trigger", params), do: data_trigger_config(params)
  defp simple_trigger_config("device_trigger", params), do: device_trigger_config(params)

  defp trigger_scope,
    do: one_of([any_device_scope(), device_scope(), group_scope()])

  defp any_device_scope,
    do: fixed_map(%{device_id: constant("*"), group_name: constant(nil)})

  defp device_scope,
    do: fixed_map(%{device_id: device_encoded_id(), group_name: constant(nil)})

  defp group_scope,
    do: fixed_map(%{device_id: constant(nil), group_name: group_name()})

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
