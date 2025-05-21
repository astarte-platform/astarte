#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.Fixtures.SimpleTriggerConfig do
  @moduledoc """
  fixtures for Astarte.Core.Triggers.SimpleTriggerConfig module.
  """
  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleTriggerConfig

  def simple_trigger_configs(interface_name, interface_major, device_id) do
    device_id = Device.encode_device_id(device_id)
    device_triggers(device_id) ++ data_triggers(interface_name, interface_major, device_id)
  end

  def device_triggers(device_id) do
    trigger1 = %SimpleTriggerConfig{
      type: "device_trigger",
      on: "device_connected",
      group_name: "simple_group",
      device_id: device_id
    }

    trigger2 = %SimpleTriggerConfig{
      type: "device_trigger",
      on: "device_disconnected",
      group_name: "simple_group",
      device_id: device_id
    }

    trigger3 = %SimpleTriggerConfig{
      type: "device_trigger",
      on: "device_error",
      group_name: "simple_group",
      device_id: device_id
    }

    [trigger1, trigger2, trigger3]
  end

  def data_triggers(interface_name, interface_major, device_id) do
    [
      %SimpleTriggerConfig{
        type: "device_trigger",
        on: "device_connected",
        group_name: "simple_group",
        device_id: device_id,
        interface_name: interface_name,
        interface_major: interface_major
      }
    ]
  end
end
