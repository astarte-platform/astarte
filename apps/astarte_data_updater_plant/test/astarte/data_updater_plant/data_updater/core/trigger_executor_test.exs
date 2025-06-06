defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.TriggerExecutorTest do
  use ExUnit.Case
  use ExUnitProperties
  import Mox
  import Astarte.Helpers.DataUpdater

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.TriggerExecutor
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.Core.Device
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.Helpers.Database, as: DatabaseTestHelper

  @moduletag :core

  setup :verify_on_exit!

  setup_all do
    DatabaseTestHelper.setup_astarte_keyspace()

    on_exit(fn ->
      DatabaseTestHelper.teardown_astarte_keyspace()
    end)

    :ok
  end

  setup do
    # Copy the TriggersHandler module for Mimic
    Mimic.copy(TriggersHandler)
    :ok
  end

  defp base_state do
    device_id = DeviceGenerator.id() |> Enum.at(0)

    %State{
      realm: "test_realm",
      device_id: device_id,
      device_triggers: %{},
      data_triggers: %{},
      trigger_id_to_policy_name: %{}
    }
  end

  defp mock_trigger_target do
    %{
      parent_trigger_id: 1,
      target_type: "http",
      target: "http://example.com/webhook"
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
      data_triggers: %{},
      trigger_id_to_policy_name: %{1 => "test_policy"}
    }
  end

  describe "execute_incoming_data_triggers/9" do
    test "executes triggers for incoming data events with empty triggers" do
      state = base_state()

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

    test "execute_incoming_data_triggers/9 executes triggers for incoming data events with configured triggers" do
      state = state_with_triggers()
      device = "test_device"
      interface = "test_interface"
      interface_id = 1
      path = "/test/path"
      endpoint_id = 1
      payload = %{"value" => 42}
      value = 42
      timestamp = DateTime.utc_now()

      Mimic.expect(TriggersHandler, :incoming_data, fn _target_with_policy_list,
                                                       realm,
                                                       device,
                                                       interface,
                                                       path,
                                                       payload,
                                                       timestamp ->
        assert device == "test_device"
        assert interface == "test_interface"
        assert path == "/test/path"
        assert payload == %{"value" => 42}
        :ok
      end)

      assert :ok =
               TriggerExecutor.execute_incoming_data_triggers(
                 state,
                 device,
                 interface,
                 interface_id,
                 path,
                 endpoint_id,
                 payload,
                 value,
                 timestamp
               )
    end

    property "does not crash for random valid input" do
      check all interface_id <- integer(),
                endpoint_id <- integer(),
                payload <- binary(),
                value <- term(),
                timestamp <- integer(1_600_000_000..2_000_000_000),
                device_id <- DeviceGenerator.id() do
        state = base_state()

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
  end

  describe "execute_pre_change_triggers/9" do
    test "executes triggers for pre-change events with empty triggers" do
      triggers = {[], [], [], []}
      state = base_state()

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
      state = state_with_triggers()
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
                                                      realm,
                                                      device,
                                                      interface,
                                                      path,
                                                      _old_bson_value,
                                                      _payload,
                                                      timestamp ->
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

    test "does not execute triggers when value remains the same" do
      trigger_target = mock_trigger_target()
      triggers = {[%{trigger_targets: [trigger_target]}], [], [], []}
      state = base_state()

      # No expectations set for TriggersHandler since it shouldn't be called

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
    test "executes triggers for post-change events with empty triggers" do
      triggers = {[], [], [], []}
      state = base_state()

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
      state = state_with_triggers()
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
                                                      realm,
                                                      device,
                                                      interface,
                                                      path,
                                                      _payload,
                                                      timestamp ->
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
      state = state_with_triggers()
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
                                                      realm,
                                                      device,
                                                      interface,
                                                      path,
                                                      timestamp ->
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
      state = state_with_triggers()
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
                                                              realm,
                                                              device,
                                                              interface,
                                                              path,
                                                              _old_bson_value,
                                                              _payload,
                                                              timestamp ->
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
    test "executes triggers for device error events with empty triggers" do
      state = base_state()

      assert :ok ==
               TriggerExecutor.execute_device_error_triggers(
                 state,
                 "test_error",
                 %{"details" => "test details"},
                 1_600_000_000_000_000
               )
    end

    test "execute_device_error_triggers/4 executes triggers for device error events with configured triggers" do
      state = state_with_triggers()
      error_name = "test_error"
      error_metadata = %{"details" => "test details"}
      timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

      Mimic.expect(TriggersHandler, :device_error, fn _target_with_policy_list,
                                                      realm,
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

      Mimic.expect(TriggersHandler, :device_error, fn _target_with_policy_list,
                                                      realm,
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
