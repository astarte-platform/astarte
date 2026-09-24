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

defmodule Astarte.DataAccess.Adapters.GroupTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Group
  import Astarte.DataAccess.Adapters.Group

  alias Astarte.Core.Device
  alias Astarte.DataAccess.Groups.Group
  alias Astarte.DataAccess.Groups.GroupedDevice

  describe "from core group to data access changes" do
    property "maps a group and its devices" do
      check all %{device_ids: device_ids, name: group_name} = group <- group(),
                insertion_uuids <-
                  binary(length: 16) |> list_of(length: length(device_ids)) do
        source = Map.put(group, :insertion_uuids, insertion_uuids)
        %{group: group, grouped_devices: grouped_devices} = from_core_group_to_change(source)

        expected_grouped_devices =
          for {device_id, insertion_uuid} <- Enum.zip(device_ids, insertion_uuids) do
            %{
              device_id: device_id,
              group_name: group_name,
              insertion_uuid: insertion_uuid
            }
          end

        assert %Ecto.Changeset{valid?: true} = Group.changeset(%Group{}, group)

        assert group == %{
                 devices: Enum.map(device_ids, &Device.encode_device_id/1),
                 group_name: group_name
               }

        for grouped_device <- grouped_devices do
          assert %GroupedDevice{} = struct(GroupedDevice, grouped_device)
        end

        assert grouped_devices == expected_grouped_devices
      end
    end
  end
end
