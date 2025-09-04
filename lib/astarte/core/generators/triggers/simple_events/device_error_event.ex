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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.DeviceErrorEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event DeviceErrorEvent struct.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Triggers.SimpleEvents.DeviceErrorEvent

  alias Astarte.Utilities.Map, as: MapUtilities

  @spec device_error_event() :: StreamData.t(DeviceErrorEvent.t())
  @spec device_error_event(keyword :: keyword()) :: StreamData.t(DeviceErrorEvent.t())
  def device_error_event(params \\ []) do
    params gen all error_name <- error_name(),
                   metadata <- metadata(),
                   params: params do
      %DeviceErrorEvent{
        error_name: error_name,
        metadata: metadata
      }
    end
  end

  @doc """
  Convert this struct/stream to changes
  """
  @spec to_changes(DeviceErrorEvent.t()) :: StreamData.t(map())
  def to_changes(data) when not is_struct(data, StreamData),
    do: data |> constant() |> to_changes()

  @spec to_changes(StreamData.t(DeviceErrorEvent.t())) :: StreamData.t(map())
  def to_changes(gen) do
    gen all %DeviceErrorEvent{
              error_name: error_name,
              metadata: metadata
            } <- gen do
      %{
        error_name: error_name,
        metadata: metadata
      }
      |> MapUtilities.clean()
    end
  end

  defp error_name, do: one_of([nil, string(:utf8)])

  defp metadata,
    do: map_of(string(:utf8), string(:utf8), min_length: 0, max_length: 10)
end
