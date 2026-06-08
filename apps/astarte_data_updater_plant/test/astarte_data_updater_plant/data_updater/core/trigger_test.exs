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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.TriggerTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.Trigger
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.DataUpdaterPlant.TriggersHandler

  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Astarte.Cases.DataUpdater
  use Astarte.Cases.Trigger
  use ExUnitProperties

  @moduletag :data_updater

  setup_all :populate_interfaces

  defp interface_descriptor(interface, major) do
    interface_id = CQLUtils.interface_id(interface, major)

    %InterfaceDescriptor{
      name: interface,
      major_version: major,
      minor_version: 1,
      automaton: {[], []},
      storage: "individual_properties",
      storage_type: :multi_interface_individual_properties_dbtable,
      interface_id: interface_id,
      type: :properties,
      ownership: :device,
      aggregation: :individual
    }
  end

  defp mapping(interface_descriptor, endpoint, value_type) do
    %{name: name, major_version: major, interface_id: interface_id} = interface_descriptor
    endpoint_id = CQLUtils.endpoint_id(name, major, endpoint)

    %Mapping{
      endpoint: endpoint,
      value_type: value_type,
      endpoint_id: endpoint_id,
      interface_id: interface_id
    }
  end

  defp build_context(state, interface_name, interface_major, value_type, path, prev, value, ts) do
    hw_id = Device.encode_device_id(state.device_id)
    descriptor = interface_descriptor(interface_name, interface_major)
    mapping = mapping(descriptor, path, value_type)

    %{
      hardware_id: hw_id,
      interface: interface_name,
      path: path,
      interface_id: descriptor.interface_id,
      endpoint_id: mapping.endpoint_id,
      payload: Cyanide.encode!(%{"value" => value}),
      value: value,
      previous_value: prev,
      value_timestamp: ts,
      state: state
    }
  end

  describe "execute_pre_change_triggers/9" do
    test "execute_pre_change_triggers/9 executes triggers when value changes", context do
      state = context.state
      realm = state.realm
      value = 42
      timestamp = DateTime.utc_now()

      context =
        build_context(state, "test_interface", 1, :integer, "/test/path", nil, value, timestamp)

      Mimic.expect(TriggersHandler, :value_change, fn rec_context, _old_bson_value, _payload ->
        %{
          interface: interface,
          value_timestamp: ^timestamp,
          path: path,
          value: new_value,
          interface_id: interface_id,
          endpoint_id: endpoint_id,
          state: %{
            device_id: device,
            realm: ^realm
          }
        } = rec_context

        assert device == state.device_id
        assert interface == "test_interface"
        assert path == "/test/path"
        assert interface_id == context.interface_id
        assert endpoint_id == context.endpoint_id
        assert new_value == value
        :ok
      end)

      assert :ok = Trigger.execute_pre_change_triggers(context)
    end

    test "does not execute triggers when value remains the same", context do
      %{
        state: state
      } = context

      context =
        build_context(
          state,
          "test_interface",
          1,
          :string,
          "/test/path",
          "same_value",
          "same_value",
          1_600_000_000
        )

      Mimic.reject(&TriggersHandler.value_change/3)

      assert :ok ==
               Trigger.execute_pre_change_triggers(context)
    end
  end

  describe "execute_post_change_triggers/1" do
    test "executes path_created triggers when value changes from nil",
         context do
      state = context.state
      realm = state.realm
      value = 42
      timestamp = DateTime.utc_now()

      context =
        build_context(state, "test_interface", 1, :integer, "/test/path", nil, value, timestamp)

      Mimic.expect(TriggersHandler, :path_created, fn rec_context, _payload ->
        %{
          interface: interface,
          path: path,
          interface_id: interface_id,
          endpoint_id: endpoint_id,
          value: val,
          state: %{
            realm: ^realm,
            device_id: device
          }
        } = rec_context

        assert device == state.device_id
        assert interface == "test_interface"
        assert path == "/test/path"
        assert val == value
        assert interface_id == context.interface_id
        assert endpoint_id == context.endpoint_id
        :ok
      end)

      assert :ok = Trigger.execute_post_change_triggers(context)
    end

    test "executes path_removed triggers when value changes to nil",
         context do
      state = context.state
      realm = state.realm
      timestamp = DateTime.utc_now()

      context =
        build_context(state, "test_interface", 1, :integer, "/test/path", 42, nil, timestamp)

      Mimic.expect(TriggersHandler, :path_removed, fn rec_context ->
        %{
          interface: interface,
          path: path,
          value_timestamp: ^timestamp,
          interface_id: interface_id,
          endpoint_id: endpoint_id,
          state: %{
            realm: ^realm,
            device_id: device_id
          }
        } = rec_context

        assert device_id == state.device_id
        assert interface == "test_interface"
        assert path == "/test/path"
        assert interface_id == context.interface_id
        assert endpoint_id == context.endpoint_id
        :ok
      end)

      assert :ok = Trigger.execute_post_change_triggers(context)
    end

    test "executes value_change_applied triggers when value changes", context do
      state = context.state
      realm = state.realm
      value = 43
      timestamp = DateTime.utc_now()

      context =
        build_context(state, "test_interface", 1, :integer, "/test/path", 42, value, timestamp)

      Mimic.expect(TriggersHandler, :value_change_applied, fn rec_context,
                                                              _old_bson_value,
                                                              _payload ->
        %{
          value: new_value,
          value_timestamp: ^timestamp,
          interface: interface,
          path: path,
          interface_id: interface_id,
          endpoint_id: endpoint_id,
          state: %{
            realm: ^realm,
            device_id: device
          }
        } = rec_context

        assert device == state.device_id
        assert interface == "test_interface"
        assert path == "/test/path"
        assert new_value == value
        assert interface_id == context.interface_id
        assert endpoint_id == context.endpoint_id
        :ok
      end)

      assert :ok = Trigger.execute_post_change_triggers(context)
    end

    test "does nothing when the value stays the same", context do
      state = context.state
      value = 43
      timestamp = DateTime.utc_now()

      context =
        build_context(state, "test_interface", 1, :integer, "/test/path", value, value, timestamp)

      Mimic.reject(TriggersHandler, :path_removed, 1)
      Mimic.reject(TriggersHandler, :path_created, 2)
      Mimic.reject(TriggersHandler, :value_change_applied, 3)

      assert :ok = Trigger.execute_post_change_triggers(context)
    end

    test "does nothing when called with two nils", context do
      state = context.state
      value = nil
      timestamp = DateTime.utc_now()

      context =
        build_context(state, "test_interface", 1, :integer, "/test/path", value, value, timestamp)

      Mimic.reject(TriggersHandler, :path_removed, 1)
      Mimic.reject(TriggersHandler, :path_created, 2)
      Mimic.reject(TriggersHandler, :value_change_applied, 3)

      assert :ok = Trigger.execute_post_change_triggers(context)
    end
  end

  describe "execute_device_error_triggers/4" do
    test "execute_device_error_triggers/4 executes triggers for device error events with configured triggers",
         context do
      %{
        state: state,
        realm_name: realm,
        device: device
      } = context

      device_id = device.encoded_id
      error_name = "test_error"
      error_metadata = %{"details" => "test details"}
      timestamp = 1_600_000_000_000_000
      timestamp_ms = 160_000_000_000

      ref =
        install_volatile_trigger(state, %DeviceTrigger{device_event_type: :DEVICE_ERROR}, fn
          event, :device_error_event, ^realm, ^device_id, ^timestamp_ms, _policy ->
            assert %{error_name: ^error_name, metadata: ^error_metadata} = event
        end)

      assert :ok =
               Trigger.execute_device_error_triggers(
                 state,
                 error_name,
                 error_metadata,
                 timestamp
               )

      assert_receive ^ref
    end

    test "execute_device_error_triggers/4 handles device error with empty metadata", context do
      %{
        state: state,
        realm_name: realm,
        device: device
      } = context

      device_id = device.encoded_id
      error_name = "test_error"
      error_metadata = %{}
      timestamp = 1_600_000_000_000_000
      timestamp_ms = 160_000_000_000

      ref =
        install_volatile_trigger(state, %DeviceTrigger{device_event_type: :DEVICE_ERROR}, fn
          event, :device_error_event, ^realm, ^device_id, ^timestamp_ms, _policy ->
            assert %{error_name: ^error_name, metadata: ^error_metadata} = event
        end)

      assert :ok =
               Trigger.execute_device_error_triggers(
                 state,
                 error_name,
                 error_metadata,
                 timestamp
               )

      assert_receive ^ref
    end

    property "does not crash for random error names and metadata", %{realm_name: realm} do
      check all error_name <- string(:alphanumeric),
                error_metadata <- map_of(string(:alphanumeric), string(:alphanumeric)),
                timestamp <- integer(1_600_000_000_000_000..2_000_000_000_000_000),
                device_id <- DeviceGenerator.id() do
        state = %State{
          realm: realm,
          device_id: device_id,
          device_triggers: %{},
          data_triggers: %{},
          trigger_id_to_policy_name: %{}
        }

        assert :ok ==
                 Trigger.execute_device_error_triggers(
                   state,
                   error_name,
                   error_metadata,
                   timestamp
                 )
      end
    end
  end
end
