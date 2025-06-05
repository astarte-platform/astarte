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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.TriggerExecutorTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.TriggerExecutor
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.Core.Device
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.DataUpdaterPlant.TriggersHandler

  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  import Astarte.Helpers.DataUpdater

  @moduletag :data_updater

  setup_all %{realm_name: realm_name, device: device} do
    setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state}
  end

  defp mock_trigger_target do
    %{
      parent_trigger_id: 1,
      simple_trigger_id: 1,
      target_type: "http",
      target: "http://example.com/webhook"
    }
  end

  defp mock_data_triggers do
    %{
      # Incoming data triggers
      {:on_incoming_data, :any_interface, :any_endpoint} => [
        %{
          path_match_tokens: ["sensors", "temperature"],
          interface_id: "com.example.Sensors",
          trigger_targets: [mock_trigger_target()],
          value_match_operator: :GREATER_THAN,
          known_value: 30
        }
      ],
      {:on_incoming_data, 1, :any_endpoint} => [
        %{
          path_match_tokens: ["status"],
          interface_id: "com.example.Sensors",
          trigger_targets: [mock_trigger_target()],
          value_match_operator: :EQUAL,
          known_value: "active"
        }
      ],
      {:on_incoming_data, 1, 1} => [
        %{
          path_match_tokens: ["value"],
          interface_id: "com.example.Sensors",
          trigger_targets: [mock_trigger_target()],
          value_match_operator: :LESS_THAN,
          known_value: 100
        }
      ],
      # Value change triggers
      {:value_change, 1, 1} => [
        %{
          path_match_tokens: ["value"],
          interface_id: "com.example.Sensors",
          trigger_targets: [mock_trigger_target()],
          value_match_operator: :NOT_EQUAL,
          known_value: nil
        }
      ],
      # Path created triggers
      {:path_created, 1, 1} => [
        %{
          path_match_tokens: ["new_sensor"],
          interface_id: "com.example.Sensors",
          trigger_targets: [mock_trigger_target()],
          value_match_operator: :ANY,
          known_value: nil
        }
      ],
      # Path removed triggers
      {:path_removed, 1, 1} => [
        %{
          path_match_tokens: ["old_sensor"],
          interface_id: "com.example.Sensors",
          trigger_targets: [mock_trigger_target()],
          value_match_operator: :ANY,
          known_value: nil
        }
      ],
      # Value change applied triggers
      {:value_change_applied, 1, 1} => [
        %{
          path_match_tokens: ["value"],
          interface_id: "com.example.Sensors",
          trigger_targets: [mock_trigger_target()],
          value_match_operator: :NOT_EQUAL,
          known_value: nil
        }
      ],
      # Value stored triggers
      {:value_stored, 1, 1} => [
        %{
          path_match_tokens: ["value"],
          interface_id: "com.example.Sensors",
          trigger_targets: [mock_trigger_target()],
          value_match_operator: :EQUAL,
          known_value: 42
        }
      ]
    }
  end

  defp state_with_triggers do
    device_id = DeviceGenerator.id() |> Enum.at(0)

    %State{
      realm: "test_realm",
      device_id: device_id,
      device_triggers: %{
        on_device_error: [mock_trigger_target()]
      },
      data_triggers: mock_data_triggers(),
      trigger_id_to_policy_name: %{1 => "test_policy"}
    }
  end

  describe "execute_incoming_data_triggers/9" do
    test "executes triggers for incoming data events with empty triggers", context do
      %{
        state: state
      } = context

      Mimic.reject(&TriggersHandler.incoming_data/7)

      assert :ok ==
               TriggerExecutor.execute_incoming_data_triggers(
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

      interface = "com.example.Sensors"
      interface_id = 1
      path = "/sensors/temperature"
      endpoint_id = 1
      payload = %{"value" => 42}
      value = 42
      timestamp = System.system_time(:microsecond)

      state = %{state | data_triggers: mock_data_triggers()}

      # For the global trigger, we expect it to be called with the temperature value
      Mimic.expect(TriggersHandler, :incoming_data, fn target_with_policy_list,
                                                       realm,
                                                       device_id,
                                                       interface_name,
                                                       path_arg,
                                                       payload_arg,
                                                       ts ->
        assert realm == state.realm
        assert device_id == device.encoded_id
        assert interface_name == interface
        assert path_arg == path
        assert payload_arg == payload
        assert ts == timestamp
        :ok
      end)

      assert :ok ==
               TriggerExecutor.execute_incoming_data_triggers(
                 state,
                 device.encoded_id,
                 interface,
                 interface_id,
                 path,
                 endpoint_id,
                 payload,
                 # This value > 30, so it should trigger
                 42,
                 timestamp
               )
    end

    test "executes interface-specific triggers", context do
      %{
        state: state,
        device: device
      } = context

      interface = "com.example.Sensors"
      interface_id = 1
      path = "/sensors/temperature"
      endpoint_id = 1
      payload = %{"value" => 42}
      value = 42
      timestamp = System.system_time(:microsecond)

      state = %{state | data_triggers: mock_data_triggers()}

      # For the interface-specific trigger, we expect it to be called with the status value
      Mimic.expect(TriggersHandler, :incoming_data, fn target_with_policy_list,
                                                       realm,
                                                       device_id,
                                                       interface_name,
                                                       path_arg,
                                                       payload_arg,
                                                       ts ->
        assert realm == state.realm
        assert device_id == device.encoded_id
        assert interface_name == interface
        # This matches our mock trigger path
        assert path_arg == "/status"
        # This matches our mock trigger condition
        assert payload_arg == %{"value" => "active"}
        assert ts == timestamp
        :ok
      end)

      assert :ok ==
               TriggerExecutor.execute_incoming_data_triggers(
                 state,
                 device.encoded_id,
                 interface,
                 interface_id,
                 # Different path to test interface-specific trigger
                 "/status",
                 endpoint_id,
                 # This matches our mock trigger condition
                 %{"value" => "active"},
                 "active",
                 timestamp
               )
    end

    test "executes endpoint-specific triggers", context do
      %{
        state: state,
        device: device
      } = context

      interface = "com.example.Sensors"
      interface_id = 1
      path = "/sensors/temperature"
      endpoint_id = 1
      payload = %{"value" => 42}
      value = 42
      timestamp = System.system_time(:microsecond)

      state = %{state | data_triggers: mock_data_triggers()}

      # For the endpoint-specific trigger, we expect it to be called with the value
      Mimic.expect(TriggersHandler, :incoming_data, fn target_with_policy_list,
                                                       realm,
                                                       device_id,
                                                       interface_name,
                                                       path_arg,
                                                       payload_arg,
                                                       ts ->
        assert realm == state.realm
        assert device_id == device.encoded_id
        assert interface_name == interface
        # This matches our mock trigger path
        assert path_arg == "/value"
        # This value < 100, so it should trigger
        assert payload_arg == %{"value" => 50}
        assert ts == timestamp
        :ok
      end)

      assert :ok ==
               TriggerExecutor.execute_incoming_data_triggers(
                 state,
                 device.encoded_id,
                 interface,
                 interface_id,
                 # Different path to test endpoint-specific trigger
                 "/value",
                 endpoint_id,
                 %{"value" => 50},
                 # This value < 100, so it should trigger
                 50,
                 timestamp
               )
    end

    test "does not execute triggers when value doesn't match condition", context do
      %{
        state: state,
        device: device
      } = context

      interface = "com.example.Sensors"
      interface_id = 1
      path = "/sensors/temperature"
      endpoint_id = 1
      payload = %{"value" => 20}
      # This value < 30, so it shouldn't trigger the global trigger
      value = 20
      timestamp = System.system_time(:microsecond)

      state = %{state | data_triggers: mock_data_triggers()}

      Mimic.reject(&TriggersHandler.incoming_data/7)

      assert :ok ==
               TriggerExecutor.execute_incoming_data_triggers(
                 state,
                 device.encoded_id,
                 interface,
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
              timestamp <- integer(1_600_000_000..2_000_000_000),
              device_id <- DeviceGenerator.id() do
      %{
        state: state
      } = context

      assert :ok ==
               TriggerExecutor.execute_incoming_data_triggers(
                 state,
                 Device.encode_device_id(device_id),
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

  describe "execute_pre_change_triggers/9" do
    test "executes triggers for pre-change events with empty triggers", context do
      triggers = {[], [], [], []}

      %{
        state: state
      } = context

      Mimic.reject(&TriggersHandler.value_change/8)

      assert :ok ==
               TriggerExecutor.execute_pre_change_triggers(
                 triggers,
                 state.realm,
                 state.device_id,
                 "test.interface",
                 "/test/path",
                 "old_value",
                 "new_value",
                 1_600_000_000,
                 %{}
               )
    end

    test "execute_pre_change_triggers/9 executes triggers when value changes" do
      triggers = {[%{trigger_targets: [mock_trigger_target()]}], [], [], []}
      realm = "test_realm"
      device = "test_device"
      interface = "test_interface"
      path = "/test/path"
      previous_value = nil
      value = 42
      timestamp = DateTime.utc_now()
      trigger_id_to_policy_name_map = %{1 => "test_policy"}

      Mimic.expect(TriggersHandler, :value_change, fn _target_with_policy_list,
                                                      ^realm,
                                                      device,
                                                      interface,
                                                      path,
                                                      _old_bson_value,
                                                      _payload,
                                                      ^timestamp ->
        assert device == "test_device"
        assert interface == "test_interface"
        assert path == "/test/path"
        :ok
      end)

      assert :ok =
               TriggerExecutor.execute_pre_change_triggers(
                 triggers,
                 realm,
                 device,
                 interface,
                 path,
                 previous_value,
                 value,
                 timestamp,
                 trigger_id_to_policy_name_map
               )
    end

    test "does not execute triggers when value remains the same", context do
      trigger_target = mock_trigger_target()
      triggers = {[%{trigger_targets: [trigger_target]}], [], [], []}

      %{
        state: state
      } = context

      Mimic.reject(&TriggersHandler.value_change/8)

      assert :ok ==
               TriggerExecutor.execute_pre_change_triggers(
                 triggers,
                 state.realm,
                 state.device_id,
                 "test.interface",
                 "/test/path",
                 "same_value",
                 "same_value",
                 1_600_000_000,
                 %{1 => "test_policy"}
               )
    end
  end

  describe "execute_post_change_triggers/9" do
    test "executes triggers for post-change events with empty triggers", context do
      triggers = {[], [], [], []}

      %{
        state: state
      } = context

      Mimic.reject(&TriggersHandler.path_created/7)
      Mimic.reject(&TriggersHandler.path_removed/6)
      Mimic.reject(&TriggersHandler.value_change_applied/8)

      assert :ok ==
               TriggerExecutor.execute_post_change_triggers(
                 triggers,
                 state.realm,
                 state.device_id,
                 "test.interface",
                 "/test/path",
                 "old_value",
                 "new_value",
                 1_600_000_000,
                 %{}
               )
    end

    test "execute_post_change_triggers/9 executes path_created triggers when value changes from nil" do
      triggers = {[], [], [%{trigger_targets: [mock_trigger_target()]}], []}
      realm = "test_realm"
      device = "test_device"
      interface = "test_interface"
      path = "/test/path"
      previous_value = nil
      value = 42
      timestamp = DateTime.utc_now()
      trigger_id_to_policy_name_map = %{1 => "test_policy"}

      Mimic.expect(TriggersHandler, :path_created, fn _target_with_policy_list,
                                                      ^realm,
                                                      device,
                                                      interface,
                                                      path,
                                                      _payload,
                                                      ^timestamp ->
        assert device == "test_device"
        assert interface == "test_interface"
        assert path == "/test/path"
        :ok
      end)

      assert :ok =
               TriggerExecutor.execute_post_change_triggers(
                 triggers,
                 realm,
                 device,
                 interface,
                 path,
                 previous_value,
                 value,
                 timestamp,
                 trigger_id_to_policy_name_map
               )
    end

    test "execute_post_change_triggers/9 executes path_removed triggers when value changes to nil" do
      triggers = {[], [], [], [%{trigger_targets: [mock_trigger_target()]}]}
      realm = "test_realm"
      device = "test_device"
      interface = "test_interface"
      path = "/test/path"
      previous_value = 42
      value = nil
      timestamp = DateTime.utc_now()
      trigger_id_to_policy_name_map = %{1 => "test_policy"}

      Mimic.expect(TriggersHandler, :path_removed, fn _target_with_policy_list,
                                                      ^realm,
                                                      device,
                                                      interface,
                                                      path,
                                                      ^timestamp ->
        assert device == "test_device"
        assert interface == "test_interface"
        assert path == "/test/path"
        :ok
      end)

      assert :ok =
               TriggerExecutor.execute_post_change_triggers(
                 triggers,
                 realm,
                 device,
                 interface,
                 path,
                 previous_value,
                 value,
                 timestamp,
                 trigger_id_to_policy_name_map
               )
    end

    test "execute_post_change_triggers/9 executes value_change_applied triggers when value changes" do
      triggers = {[], [%{trigger_targets: [mock_trigger_target()]}], [], []}
      realm = "test_realm"
      device = "test_device"
      interface = "test_interface"
      path = "/test/path"
      previous_value = 42
      value = 43
      timestamp = DateTime.utc_now()
      trigger_id_to_policy_name_map = %{1 => "test_policy"}

      Mimic.expect(TriggersHandler, :value_change_applied, fn _target_with_policy_list,
                                                              ^realm,
                                                              device,
                                                              interface,
                                                              path,
                                                              _old_bson_value,
                                                              _payload,
                                                              ^timestamp ->
        assert device == "test_device"
        assert interface == "test_interface"
        assert path == "/test/path"
        :ok
      end)

      assert :ok =
               TriggerExecutor.execute_post_change_triggers(
                 triggers,
                 realm,
                 device,
                 interface,
                 path,
                 previous_value,
                 value,
                 timestamp,
                 trigger_id_to_policy_name_map
               )
    end
  end

  describe "execute_device_error_triggers/4" do
    test "executes triggers for device error events with empty triggers", context do
      %{
        state: state,
        realm_name: realm,
        device: device
      } = context

      device_id = device.encoded_id
      error_name = "test_error"
      error_metadata = %{"details" => "test details"}
      timestamp = 1_600_000_000_000_000
      timestamp_ms = 1_600_000_000_00

      Mimic.expect(TriggersHandler, :device_error, fn targets,
                                                      ^realm,
                                                      ^device_id,
                                                      ^error_name,
                                                      ^error_metadata,
                                                      ^timestamp_ms ->
        assert targets == []

        :ok
      end)

      assert :ok ==
               TriggerExecutor.execute_device_error_triggers(
                 state,
                 error_name,
                 error_metadata,
                 timestamp
               )
    end

    test "execute_device_error_triggers/4 executes triggers for device error events with configured triggers" do
      state = state_with_triggers()
      error_name = "test_error"
      error_metadata = %{"details" => "test details"}
      timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)
      realm = state.realm

      Mimic.expect(TriggersHandler, :device_error, fn _target_with_policy_list,
                                                      ^realm,
                                                      device,
                                                      error_name,
                                                      error_metadata,
                                                      _timestamp_ms ->
        assert device
        assert error_name == "test_error"
        assert error_metadata == %{"details" => "test details"}
        :ok
      end)

      assert :ok =
               TriggerExecutor.execute_device_error_triggers(
                 state,
                 error_name,
                 error_metadata,
                 timestamp
               )
    end

    test "execute_device_error_triggers/4 handles device error with empty metadata" do
      state = state_with_triggers()
      error_name = "test_error"
      error_metadata = %{}
      timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)
      realm = state.realm

      Mimic.expect(TriggersHandler, :device_error, fn _target_with_policy_list,
                                                      ^realm,
                                                      device,
                                                      error_name,
                                                      error_metadata,
                                                      _timestamp_ms ->
        assert device
        assert error_name == "test_error"
        assert error_metadata == %{}
        :ok
      end)

      assert :ok =
               TriggerExecutor.execute_device_error_triggers(
                 state,
                 error_name,
                 error_metadata,
                 timestamp
               )
    end

    property "does not crash for random error names and metadata" do
      check all error_name <- string(:alphanumeric),
                error_metadata <- map_of(string(:alphanumeric), string(:alphanumeric)),
                timestamp <- integer(1_600_000_000_000_000..2_000_000_000_000_000),
                device_id <- DeviceGenerator.id() do
        state = %State{
          realm: "test_realm",
          device_id: device_id,
          device_triggers: %{},
          data_triggers: %{},
          trigger_id_to_policy_name: %{}
        }

        assert :ok ==
                 TriggerExecutor.execute_device_error_triggers(
                   state,
                   error_name,
                   error_metadata,
                   timestamp
                 )
      end
    end
  end
end
