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

defmodule Astarte.AppEngine.API.Rooms.WatchRequestTest do
  use ExUnit.Case, async: true

  alias Astarte.AppEngine.API.Rooms.WatchRequest
  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils
  alias Ecto.Changeset

  setup_all do
    incoming_data_simple_trigger_params = %{
      "type" => "data_trigger",
      "on" => "incoming_data",
      "interface_name" => "*",
      "value_match_operator" => "*",
      "match_path" => "/*"
    }

    %{
      incoming_data_simple_trigger_params: incoming_data_simple_trigger_params
    }
  end

  describe "changeset/2" do
    @tag :regression
    test "casts the simple trigger config appropriately respecting group_name", context do
      %{incoming_data_simple_trigger_params: params} = context
      group_name = "test"

      params = %{
        name: "name",
        group_name: group_name,
        simple_trigger: params
      }

      changeset = WatchRequest.changeset(%WatchRequest{}, params)

      assert {:ok, watch_request} = Changeset.apply_action(changeset, :insert)

      tagged_simple_trigger =
        SimpleTriggerConfig.to_tagged_simple_trigger(watch_request.simple_trigger)

      assert watch_request.simple_trigger.group_name == group_name

      assert tagged_simple_trigger.object_type ==
               Utils.object_type_to_int!(:group_and_any_interface)
    end

    @tag :regression
    test "casts the simple trigger config appropriately respecting device_id", context do
      %{incoming_data_simple_trigger_params: params} = context
      device_id = Device.random_device_id() |> Device.encode_device_id()

      params = %{
        name: "name",
        device_id: device_id,
        simple_trigger: params
      }

      changeset = WatchRequest.changeset(%WatchRequest{}, params)
      assert {:ok, watch_request} = Changeset.apply_action(changeset, :insert)

      tagged_simple_trigger =
        SimpleTriggerConfig.to_tagged_simple_trigger(watch_request.simple_trigger)

      assert watch_request.simple_trigger.device_id == device_id

      assert tagged_simple_trigger.object_type ==
               Utils.object_type_to_int!(:device_and_any_interface)
    end
  end
end
