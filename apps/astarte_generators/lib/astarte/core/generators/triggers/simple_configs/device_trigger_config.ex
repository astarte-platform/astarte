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
  This module provides generators for Astarte Trigger Simple Config DeviceTrigger structs.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Interface, only: [interface: 0]
  import Astarte.Core.Generators.Triggers.SimpleConfigs.Scope, only: [trigger_scope: 0]

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger

  @device_trigger_conditions [
    :DEVICE_CONNECTED,
    :DEVICE_DISCONNECTED,
    :DEVICE_EMPTY_CACHE_RECEIVED,
    :DEVICE_ERROR,
    :INCOMING_INTROSPECTION,
    :INTERFACE_ADDED,
    :INTERFACE_REMOVED,
    :INTERFACE_MINOR_UPDATED,
    :DEVICE_REGISTERED,
    :DEVICE_DELETION_STARTED,
    :DEVICE_DELETION_FINISHED
  ]

  @interface_match_conditions [:INTERFACE_ADDED, :INTERFACE_REMOVED]

  @spec device_trigger_config() :: StreamData.t(DeviceTrigger.t())
  @spec device_trigger_config(keyword :: keyword()) :: StreamData.t(DeviceTrigger.t())
  def device_trigger_config(params \\ []) do
    params gen all scope <- trigger_scope(),
                   %{device_id: device_id, group_name: group_name} =
                     Map.merge(%{device_id: nil, group_name: nil}, scope),
                   device_event_type <- member_of(@device_trigger_conditions),
                   interface <- device_trigger_interface(device_event_type),
                   {interface_name, interface_major} = interface_reference(interface),
                   params: params do
      %DeviceTrigger{
        device_event_type: device_event_type,
        group_name: group_name,
        device_id: device_id,
        interface_name: interface_name,
        interface_major: interface_major
      }
    end
  end

  defp device_trigger_interface(device_event_type)
       when device_event_type in @interface_match_conditions,
       do: one_of([constant(:any_interface), interface()])

  defp device_trigger_interface(:INTERFACE_MINOR_UPDATED), do: interface()
  defp device_trigger_interface(_device_event_type), do: constant(:no_interface)

  defp interface_reference(:any_interface), do: {"*", 0}
  defp interface_reference(:no_interface), do: {nil, 0}

  defp interface_reference(%Interface{name: name, major_version: major_version}),
    do: {name, major_version}
end
