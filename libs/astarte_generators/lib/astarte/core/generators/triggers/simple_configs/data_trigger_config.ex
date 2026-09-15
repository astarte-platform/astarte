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
  This module provides generators for Astarte Trigger Simple Config DataTrigger structs.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Interface, only: [interface: 0]
  import Astarte.Core.Generators.Mapping.BSONValue, only: [bson_value_type: 1]
  import Astarte.Core.Generators.Triggers.SimpleConfigs.Scope, only: [trigger_scope: 0]

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger

  @data_trigger_conditions [
    :INCOMING_DATA,
    :VALUE_CHANGE,
    :VALUE_CHANGE_APPLIED,
    :PATH_CREATED,
    :PATH_REMOVED,
    :VALUE_STORED
  ]

  @data_trigger_operators [
    :ANY,
    :EQUAL_TO,
    :NOT_EQUAL_TO,
    :GREATER_THAN,
    :GREATER_OR_EQUAL_TO,
    :LESS_THAN,
    :LESS_OR_EQUAL_TO,
    :CONTAINS,
    :NOT_CONTAINS
  ]

  @datastream_trigger_conditions [
    :INCOMING_DATA,
    :PATH_CREATED,
    :VALUE_STORED
  ]

  @properties_wildcard_trigger_conditions [
    :INCOMING_DATA,
    :PATH_CREATED,
    :PATH_REMOVED,
    :VALUE_STORED
  ]

  @spec data_trigger_config() :: StreamData.t(DataTrigger.t())
  @spec data_trigger_config(keyword :: keyword()) :: StreamData.t(DataTrigger.t())
  def data_trigger_config(params \\ []) do
    params gen all scope <- trigger_scope(),
                   %{device_id: device_id, group_name: group_name} =
                     Map.merge(%{device_id: nil, group_name: nil}, scope),
                   interface <- data_trigger_interface(),
                   {interface_name, interface_major} = interface_reference(interface),
                   trigger_mapping <- data_trigger_mapping(interface),
                   match_path <- data_trigger_path(interface, trigger_mapping),
                   data_trigger_type <- data_trigger_condition(interface, match_path),
                   value_match_operator <- data_trigger_operator(match_path),
                   known_value <- data_trigger_known_value(value_match_operator, trigger_mapping),
                   params: params do
      %DataTrigger{
        data_trigger_type: data_trigger_type,
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

  defp data_trigger_interface, do: one_of([constant(:any_interface), interface()])

  defp interface_reference(:any_interface), do: {"*", 0}

  defp interface_reference(%Interface{name: name, major_version: major_version}),
    do: {name, major_version}

  defp data_trigger_mapping(:any_interface), do: constant(nil)
  defp data_trigger_mapping(%Interface{aggregation: :object}), do: constant(nil)

  defp data_trigger_mapping(%Interface{aggregation: :individual, mappings: mappings}),
    do: member_of(mappings)

  defp data_trigger_path(:any_interface, nil), do: constant("/*")
  defp data_trigger_path(%Interface{aggregation: :object}, nil), do: constant("/*")

  defp data_trigger_path(
         %Interface{aggregation: :individual},
         %Mapping{endpoint: endpoint}
       ),
       do: one_of([constant("/*"), constant(endpoint)])

  defp data_trigger_condition(:any_interface, "/*"), do: constant(:INCOMING_DATA)

  defp data_trigger_condition(%Interface{aggregation: :object}, "/*"),
    do: constant(:INCOMING_DATA)

  defp data_trigger_condition(%Interface{type: :datastream}, _match_path),
    do: member_of(@datastream_trigger_conditions)

  defp data_trigger_condition(%Interface{type: :properties}, "/*"),
    do: member_of(@properties_wildcard_trigger_conditions)

  defp data_trigger_condition(%Interface{type: :properties}, _match_path),
    do: member_of(@data_trigger_conditions)

  defp data_trigger_operator("/*"), do: constant(:ANY)
  defp data_trigger_operator(_match_path), do: member_of(@data_trigger_operators)

  defp data_trigger_known_value(:ANY, _trigger_mapping), do: constant(nil)

  defp data_trigger_known_value(_operator, %Mapping{value_type: value_type}),
    do: bson_value_type(value_type)
end
