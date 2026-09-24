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
  Mappings from an Astarte group to its database fields.
  """
  use Astarte.Adapters

  alias Astarte.Core.Device
  alias Astarte.DataAccess.UUID

  @type source :: %{
          required(:device_ids) => [Device.device_id()],
          required(:insertion_uuids) => [UUID.t()],
          required(:name) => String.t()
        }

  transform from_core_group_to_change do
    @source source()
    @returns %{
      group: map(),
      grouped_devices: [map()]
    }

    field :group, &group_change/1
    field :grouped_devices, &grouped_device_changes/1
  end

  transformp group_change do
    field :group_name <- :name
    field :devices <- :device_ids, &encoded_device_ids/1
  end

  transformp grouped_device_change do
    keep :device_id, :group_name, :insertion_uuid
  end

  defp encoded_device_ids(device_ids), do: Enum.map(device_ids, &Device.encode_device_id/1)

  defp grouped_device_changes(%{
         device_ids: device_ids,
         insertion_uuids: insertion_uuids,
         name: group_name
       }),
       do:
         Enum.zip_with(
           device_ids,
           insertion_uuids,
           &grouped_device_change(%{
             device_id: &1,
             group_name: group_name,
             insertion_uuid: &2
           })
         )
end
