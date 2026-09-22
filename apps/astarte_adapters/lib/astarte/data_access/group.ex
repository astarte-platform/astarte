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

defmodule Astarte.DataAccess.Adapters.Group do
  @moduledoc """
  Mappings to Astarte.DataAccess.Groups.Group and Astarte.DataAccess.Groups.GroupedDevice.
  """
  use Astarte.Adapters

  alias Astarte.Core.Device
  alias Astarte.DataAccess.UUID

  @type source :: %{
          group: map(),
          insertion_uuids: [UUID.t()]
        }

  transform from_core_group_to_change do
    @source source()
    @returns %{
      group: map(),
      grouped_devices: [map()]
    }

    pre_process &pre_process/1

    field :group_name <- :name
    field :devices <- :device_ids, &encoded_device_ids/1
    field :grouped_devices, &grouped_devices/1

    post_process &post_process/1
  end

  defp pre_process(%{group: group, insertion_uuids: insertion_uuids}),
    do: Map.put(group, :insertion_uuids, insertion_uuids)

  defp encoded_device_ids(device_ids), do: Enum.map(device_ids, &Device.encode_device_id/1)

  defp grouped_devices(%{
         device_ids: device_ids,
         insertion_uuids: insertion_uuids,
         name: group_name
       }),
       do: grouped_devices(device_ids, insertion_uuids, group_name)

  defp grouped_devices([], [], _group_name), do: []

  defp grouped_devices([device_id | device_ids], [insertion_uuid | insertion_uuids], group_name) do
    [
      %{
        device_id: device_id,
        group_name: group_name,
        insertion_uuid: insertion_uuid
      }
      | grouped_devices(device_ids, insertion_uuids, group_name)
    ]
  end

  defp post_process(source) do
    {grouped_devices, group} = Map.pop(source, :grouped_devices)
    %{group: group, grouped_devices: grouped_devices}
  end
end
