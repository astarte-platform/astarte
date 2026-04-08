#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Astarte.Core.Generators.Group do
  @moduledoc """
  This module provides generators for Astarte Groups.

  See https://docs.astarte-platform.org/astarte/0.11/065-groups.html
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Generators.Device, as: DeviceGenerator

  @max_subpath_count 10
  @max_subpath_length 20
  @max_devices_count 10

  @doc """
  Generates a valid Astarte Group name.
  """
  @spec name() :: StreamData.t(String.t())
  def name do
    string(:ascii, min_length: 1, max_length: @max_subpath_length)
    |> uniq_list_of(
      min_length: 1,
      max_length: @max_subpath_count
    )
    |> map(&Enum.join(&1, "/"))
    |> filter(&(String.first(&1) not in ["@", "~", "\s"]))
  end

  @doc """
  Generates a valid Astarte Group.
  """
  @spec group() :: StreamData.t(map())
  @spec group(params :: keyword()) :: StreamData.t(map())
  def group(params \\ []) do
    params gen all name <- name(),
                   device_ids <-
                     DeviceGenerator.device()
                     |> map(& &1.id)
                     |> list_of(min_length: 1, max_length: @max_devices_count),
                   params: params do
      %{
        name: name,
        device_ids: device_ids
      }
    end
  end
end
