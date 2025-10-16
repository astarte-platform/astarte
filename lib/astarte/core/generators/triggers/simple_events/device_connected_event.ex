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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.DeviceConnectedEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event DeviceConnectedEvent struct.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent

  alias Astarte.Common.Generators.Ip, as: IpGenerator

  @spec device_connected_event() :: StreamData.t(DeviceConnectedEvent.t())
  @spec device_connected_event(keyword :: keyword()) :: StreamData.t(DeviceConnectedEvent.t())
  def device_connected_event(params \\ []) do
    params gen all device_ip_address <- device_ip_address(),
                   params: params do
      %DeviceConnectedEvent{
        device_ip_address: device_ip_address
      }
    end
  end

  defp device_ip_address,
    do:
      IpGenerator.ip(:ipv4)
      |> map(&Tuple.to_list/1)
      |> map(&Enum.join(&1, "."))
end
