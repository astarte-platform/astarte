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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.DeviceDisconnectedEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event DeviceDisconnectedEvent struct.
  """
  use ExUnitProperties

  alias Astarte.Core.Triggers.SimpleEvents.DeviceDisconnectedEvent

  alias Astarte.Utilities.Map, as: MapUtilities

  @spec device_disconnected_event() :: StreamData.t(DeviceDisconnectedEvent.t())
  def device_disconnected_event, do: constant(%DeviceDisconnectedEvent{})

  @doc """
  Convert this struct/stream to changes
  """
  @spec to_changes(DeviceDisconnectedEvent.t()) :: StreamData.t(map())
  def to_changes(data) when not is_struct(data, StreamData),
    do: data |> constant() |> to_changes()

  @spec to_changes(StreamData.t(DeviceDisconnectedEvent.t())) :: StreamData.t(map())
  def to_changes(gen) do
    gen all device_disconnected_event <- gen do
      device_disconnected_event
      |> Map.from_struct()
      |> MapUtilities.clean()
    end
  end
end
