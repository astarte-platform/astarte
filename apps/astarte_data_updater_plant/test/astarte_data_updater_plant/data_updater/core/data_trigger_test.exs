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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.DataTriggerTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.DataUpdaterPlant.TriggersHandler

  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  import Astarte.Helpers.DataUpdater

  @moduletag :data_updater

  setup_all :populate_interfaces

  setup_all %{realm_name: realm_name, device: device} do
    setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state}
  end

  defp mock_trigger_target do
    %AMQPTriggerTarget{
      parent_trigger_id: :uuid.get_v4(),
      simple_trigger_id: :uuid.get_v4(),
      static_headers: [],
      routing_key: AMQPTestHelper.events_routing_key()
    }
  end

  defp mock_data_trigger(state, %DataTrigger{} = simple_trigger) do
    data_trigger =
      Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils.simple_trigger_to_data_trigger(
        simple_trigger
      )

    data_trigger = %{data_trigger | trigger_targets: [mock_trigger_target()]}

    event_type =
      Astarte.DataUpdaterPlant.DataUpdater.EventTypeUtils.pretty_data_trigger_type(
        simple_trigger.data_trigger_type
      )

    interface_id = data_trigger.interface_id

    endpoint_id =
      if simple_trigger.match_path == "/*" do
        :any_endpoint
      else
        CQLUtils.endpoint_id(
          simple_trigger.interface_name,
          simple_trigger.interface_major,
          simple_trigger.match_path
        )
      end

    key = {event_type, interface_id, endpoint_id}

    %{state | data_triggers: %{key => [data_trigger]}}
  end

  describe "execute_incoming_data_triggers/9" do
    test "doesn't execute triggers for incoming data events with empty triggers", context do
      %{
        state: state
      } = context

      Mimic.reject(&TriggersHandler.incoming_data/7)

      assert :ok ==
               Core.DataTrigger.execute_incoming_data_triggers(
                 state,
                 "encoded_device_id",
                 "test.interface",
                 1,
                 "/test/path",
                 1,
                 <<0, 1, 2, 3>>,
                 42,
                 1_600_000_000
               )
    end

    test "executes global triggers for any interface/endpoint", context do
      %{
        state: state,
        device: device
      } = context

      realm = state.realm
      device_id = device.encoded_id
      interface_name = "com.example.Sensors"
      interface_major = 1
      path = "/sensors/temperature"
      interface_id = CQLUtils.interface_id(interface_name, interface_major)
      endpoint_id = CQLUtils.endpoint_id(interface_name, interface_major, path)
      value = 42
      payload = Cyanide.encode!(%{"value" => value})
      timestamp = 1_600_000_000_000_000

      state =
        mock_data_trigger(state, %DataTrigger{
          interface_name: "*",
          data_trigger_type: :INCOMING_DATA,
          match_path: "/*",
          value_match_operator: :LESS_THAN,
          known_value: Cyanide.encode!(%{v: 50})
        })

      Mimic.expect(TriggersHandler, :incoming_data, fn _target_with_policy_list,
                                                       ^realm,
                                                       ^device_id,
                                                       ^interface_name,
                                                       ^path,
                                                       ^payload,
                                                       ^timestamp ->
        :ok
      end)

      assert :ok ==
               Core.DataTrigger.execute_incoming_data_triggers(
                 state,
                 device.encoded_id,
                 interface_name,
                 interface_id,
                 path,
                 endpoint_id,
                 payload,
                 value,
                 timestamp
               )
    end

    test "executes interface-specific triggers", context do
      %{
        state: state,
        device: device
      } = context

      realm = state.realm
      device_id = device.encoded_id
      interface_name = "com.example.Sensors"
      interface_major = 1
      path = "/sensors/temperature"
      interface_id = CQLUtils.interface_id(interface_name, interface_major)
      endpoint_id = CQLUtils.endpoint_id(interface_name, interface_major, path)
      value = 42
      payload = Cyanide.encode!(%{"value" => value})
      timestamp = 1_600_000_000_000_000

      state =
        mock_data_trigger(state, %DataTrigger{
          interface_name: interface_name,
          interface_major: interface_major,
          data_trigger_type: :INCOMING_DATA,
          match_path: "/*",
          value_match_operator: :LESS_THAN,
          known_value: Cyanide.encode!(%{v: 50})
        })

      Mimic.expect(TriggersHandler, :incoming_data, fn _target_with_policy_list,
                                                       ^realm,
                                                       ^device_id,
                                                       ^interface_name,
                                                       ^path,
                                                       ^payload,
                                                       ^timestamp ->
        :ok
      end)

      assert :ok ==
               Core.DataTrigger.execute_incoming_data_triggers(
                 state,
                 device.encoded_id,
                 interface_name,
                 interface_id,
                 path,
                 endpoint_id,
                 payload,
                 value,
                 timestamp
               )
    end

    test "executes endpoint-specific triggers", context do
      %{
        state: state,
        device: device
      } = context

      realm = state.realm
      device_id = device.encoded_id
      interface_name = "com.example.Sensors"
      interface_major = 1
      path = "/sensors/temperature"
      interface_id = CQLUtils.interface_id(interface_name, interface_major)
      endpoint_id = CQLUtils.endpoint_id(interface_name, interface_major, path)
      value = 42
      payload = Cyanide.encode!(%{"value" => value})
      timestamp = 1_600_000_000_000_000

      state =
        mock_data_trigger(state, %DataTrigger{
          interface_name: interface_name,
          interface_major: interface_major,
          data_trigger_type: :INCOMING_DATA,
          match_path: "/sensors/temperature",
          value_match_operator: :LESS_THAN,
          known_value: Cyanide.encode!(%{v: 50})
        })

      Mimic.expect(TriggersHandler, :incoming_data, fn _target_with_policy_list,
                                                       ^realm,
                                                       ^device_id,
                                                       ^interface_name,
                                                       ^path,
                                                       ^payload,
                                                       ^timestamp ->
        :ok
      end)

      assert :ok ==
               Core.DataTrigger.execute_incoming_data_triggers(
                 state,
                 device.encoded_id,
                 interface_name,
                 interface_id,
                 path,
                 endpoint_id,
                 payload,
                 value,
                 timestamp
               )
    end

    test "does not execute triggers when value doesn't match condition", context do
      %{
        state: state,
        device: device
      } = context

      interface_name = "com.example.Sensors"
      interface_major = 1
      path = "/sensors/temperature"
      interface_id = CQLUtils.interface_id(interface_name, interface_major)
      endpoint_id = CQLUtils.endpoint_id(interface_name, interface_major, path)
      value = 60
      payload = Cyanide.encode!(%{"value" => value})
      timestamp = 1_600_000_000_000_000

      state =
        mock_data_trigger(state, %DataTrigger{
          interface_name: interface_name,
          interface_major: interface_major,
          data_trigger_type: :INCOMING_DATA,
          match_path: "/sensors/temperature",
          value_match_operator: :LESS_THAN,
          known_value: Cyanide.encode!(%{v: 50})
        })

      Mimic.reject(&TriggersHandler.incoming_data/7)

      assert :ok ==
               Core.DataTrigger.execute_incoming_data_triggers(
                 state,
                 device.encoded_id,
                 interface_name,
                 interface_id,
                 path,
                 endpoint_id,
                 payload,
                 value,
                 timestamp
               )
    end
  end

  property "does not crash for random valid input", context do
    check all interface_id <- integer(),
              endpoint_id <- integer(),
              payload <- binary(),
              value <- term(),
              timestamp <- integer(1_600_000_000..2_000_000_000) do
      %{
        state: state,
        device: device
      } = context

      assert :ok ==
               Core.DataTrigger.execute_incoming_data_triggers(
                 state,
                 device.encoded_id,
                 "iface",
                 interface_id,
                 "/path",
                 endpoint_id,
                 payload,
                 value,
                 timestamp
               )
    end
  end
end
