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

defmodule Astarte.RealmManagement.Generators.GroupedDevice do
  @moduledoc """
  Generator for `Astarte.DataAccess.Groups.GroupedDevice` structure
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.DataAccess.Groups.GroupedDevice

  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Group, as: GroupGenerator

  @doc false
  @spec grouped_device(params :: keyword()) :: StreamData.t(GroupedDevice.t())
  def grouped_device(params) do
    params gen all device_id <- DeviceGenerator.id(),
                   group_name <- GroupGenerator.name(),
                   insertion_uuid <- repeatedly(&UUID.uuid1/0),
                   params: params do
      %GroupedDevice{
        device_id: device_id,
        group_name: group_name,
        insertion_uuid: insertion_uuid
      }
    end
  end
end
