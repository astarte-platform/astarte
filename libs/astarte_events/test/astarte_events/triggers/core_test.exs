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

defmodule Astarte.Events.Triggers.CoreTest do
  use Astarte.Cases.Data, async: true

  import Mimic

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger,
    as: ProtobufDataTrigger

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger,
    as: ProtobufDeviceTrigger

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils
  alias Astarte.Events.Triggers.Core
  alias Astarte.Events.Triggers.DataTrigger, as: DataTriggerWithTargets
  alias Astarte.Events.TriggersHandler.Core, as: TriggersHandlerCore

  setup :verify_on_exit!

  @any_device_object_id Utils.any_device_object_id()
  @any_device_object_type Utils.object_type_to_int!(:any_device)
  @device_object_type Utils.object_type_to_int!(:device)
  @group_object_type Utils.object_type_to_int!(:group)
  @any_interface_object_id Utils.any_interface_object_id()
  @any_interface_object_type Utils.object_type_to_int!(:any_interface)
  @interface_object_type Utils.object_type_to_int!(:interface)
  @device_and_any_interface_object_type Utils.object_type_to_int!(:device_and_any_interface)
  @device_and_interface_object_type Utils.object_type_to_int!(:device_and_interface)
  @group_and_any_interface_object_type Utils.object_type_to_int!(:group_and_any_interface)
  @group_and_interface_object_type Utils.object_type_to_int!(:group_and_interface)

  describe "object_from_subject/1" do
    test "returns the expected value for :any_device" do
      assert Core.object_from_subject(:any_device) ==
               {@any_device_object_type, @any_device_object_id}
    end

    test "returns the expected value for :device_id" do
      device_id = Device.random_device_id()
      assert Core.object_from_subject({:device_id, device_id}) == {@device_object_type, device_id}
    end

    test "returns the expected value for :group" do
      group_name = "group"
      group_id = Utils.get_group_object_id(group_name)
      assert Core.object_from_subject({:group, group_name}) == {@group_object_type, group_id}
    end

    test "returns the expected value for :any_interface" do
      assert Core.object_from_subject(:any_interface) ==
               {@any_interface_object_type, @any_interface_object_id}
    end

    test "returns the expected value for :interface" do
      interface_id = UUID.uuid4(:raw)

      assert Core.object_from_subject({:interface, interface_id}) ==
               {@interface_object_type, interface_id}
    end

    test "returns the expected value for :group_and_any_interface" do
      group_name = "group"
      group_id = Utils.get_group_and_any_interface_object_id(group_name)

      assert Core.object_from_subject({:group_and_any_interface, group_name}) ==
               {@group_and_any_interface_object_type, group_id}
    end

    test "returns the expected value for :group_and_interface" do
      group_name = "group"
      interface_id = UUID.uuid4(:raw)
      object_id = Utils.get_group_and_interface_object_id(group_name, interface_id)

      assert Core.object_from_subject({:group_and_interface, group_name, interface_id}) ==
               {@group_and_interface_object_type, object_id}
    end

    test "returns the expected value for :device_and_any_interface" do
      device_id = Device.random_device_id()
      object_id = Utils.get_device_and_any_interface_object_id(device_id)

      assert Core.object_from_subject({:device_and_any_interface, device_id}) ==
               {@device_and_any_interface_object_type, object_id}
    end

    test "returns the expected value for :device_and_interface" do
      device_id = Device.random_device_id()
      interface_id = UUID.uuid4(:raw)
      object_id = Utils.get_device_and_interface_object_id(device_id, interface_id)

      assert Core.object_from_subject({:device_and_interface, device_id, interface_id}) ==
               {@device_and_interface_object_type, object_id}
    end
  end

  describe "register_targets/2" do
    test "registers all targets", %{realm_name: realm} do
      target1 = %AMQPTriggerTarget{exchange: "exchange1"}
      target2 = %AMQPTriggerTarget{exchange: "exchange2"}

      simple_trigger_list = [
        {:on_device_connection, target1},
        {:on_device_disconnection, target2}
      ]

      TriggersHandlerCore
      |> expect(:register_target, 2, fn ^realm, target ->
        send(self(), {:register_target, target})
        :ok
      end)

      Core.register_targets(realm, simple_trigger_list)

      assert_receive {:register_target, ^target1}
      assert_receive {:register_target, ^target2}
    end
  end

  describe "trigger_subject/2 for device_trigger" do
    test "returns :any_device when device_id and group_name are nil" do
      trigger = %ProtobufDeviceTrigger{
        device_id: nil,
        group_name: nil
      }

      assert {:ok, :any_device} =
               Core.trigger_subject(:device_trigger, trigger)
    end

    test "returns :any_device when device_id is '*'" do
      trigger = %ProtobufDeviceTrigger{
        device_id: "*",
        group_name: nil
      }

      assert {:ok, :any_device} =
               Core.trigger_subject(:device_trigger, trigger)
    end

    test "returns {:device_id, device_id} when a device_id is provided" do
      device_id = DeviceGenerator.encoded_id() |> Enum.at(0)
      {:ok, decoded_device_id} = Device.decode_device_id(device_id, allow_extended_id: true)

      trigger = %ProtobufDeviceTrigger{
        device_id: device_id,
        group_name: nil
      }

      assert {:ok, {:device_id, decoded_device_id}} ==
               Core.trigger_subject(:device_trigger, trigger)
    end

    test "returns {:group, group_name} when group_name is provided" do
      trigger = %ProtobufDeviceTrigger{
        device_id: nil,
        group_name: "group"
      }

      assert {:ok, {:group, "group"}} =
               Core.trigger_subject(:device_trigger, trigger)
    end
  end

  describe "data_trigger_to_key/3" do
    test "returns endpoint for valid interface and path", %{realm_name: realm} do
      interface = install_interface(realm)
      descriptor = InterfaceDescriptor.from_db_result!(interface)

      interface_id = descriptor.interface_id

      state = %{
        interfaces: %{descriptor.name => descriptor},
        interface_ids_to_name: %{interface_id => descriptor.name}
      }

      data_trigger = %DataTrigger{
        interface_id: interface_id,
        path_match_tokens: ["time", "from"],
        trigger_targets: []
      }

      assert {:ok, {:on_incoming_data, ^interface_id, endpoint}} =
               Core.data_trigger_to_key(state, data_trigger, :on_incoming_data)

      assert endpoint != :any_endpoint
    end

    test "returns :interface_not_found when interface is missing" do
      interface_id = UUID.uuid4(:raw)

      state = %{
        interfaces: %{},
        interface_ids_to_name: %{interface_id => "missing.interface"}
      }

      data_trigger = %DataTrigger{
        interface_id: interface_id,
        path_match_tokens: ["time", "from"],
        trigger_targets: []
      }

      assert {:error, :interface_not_found} =
               Core.data_trigger_to_key(state, data_trigger, :on_incoming_data)
    end

    test "returns :invalid_match_path when path is not in the interface", %{realm_name: realm} do
      interface = install_interface(realm)
      descriptor = InterfaceDescriptor.from_db_result!(interface)

      interface_id = descriptor.interface_id

      state = %{
        interfaces: %{descriptor.name => descriptor},
        interface_ids_to_name: %{interface_id => descriptor.name}
      }

      data_trigger = %DataTrigger{
        interface_id: interface_id,
        path_match_tokens: ["invalid", "path"],
        trigger_targets: []
      }

      assert {:error, :invalid_match_path} =
               Core.data_trigger_to_key(state, data_trigger, :on_incoming_data)
    end
  end

  describe "trigger_subject/2 for data_trigger" do
    test "returns :any_interface when device_id is nil and interface is '*'" do
      trigger = %ProtobufDataTrigger{
        device_id: nil,
        group_name: nil,
        interface_name: "*"
      }

      assert {:ok, :any_interface} =
               Core.trigger_subject(:data_trigger, trigger)
    end

    test "returns {:interface, interface_id} when interface is specified" do
      interface_id = CQLUtils.interface_id("com.example.Test", 1)

      trigger = %ProtobufDataTrigger{
        device_id: nil,
        group_name: nil,
        interface_name: "com.example.Test",
        interface_major: 1
      }

      assert {:ok, {:interface, ^interface_id}} =
               Core.trigger_subject(:data_trigger, trigger)
    end

    test "returns {:group_and_any_interface, group} when group is specified" do
      trigger = %ProtobufDataTrigger{
        device_id: nil,
        group_name: "group",
        interface_name: "*"
      }

      assert {:ok, {:group_and_any_interface, "group"}} =
               Core.trigger_subject(:data_trigger, trigger)
    end

    test "returns {:group_and_interface, group, interface_id} when group and interface are specified" do
      interface_id = CQLUtils.interface_id("com.example.Test", 1)

      trigger = %ProtobufDataTrigger{
        device_id: nil,
        group_name: "group",
        interface_name: "com.example.Test",
        interface_major: 1
      }

      assert {:ok, {:group_and_interface, "group", ^interface_id}} =
               Core.trigger_subject(:data_trigger, trigger)
    end

    test "returns {:device_and_any_interface, device_id} when device is specified and interface is '*'" do
      device_id = DeviceGenerator.encoded_id() |> Enum.at(0)
      {:ok, decoded_device_id} = Device.decode_device_id(device_id, allow_extended_id: true)

      trigger = %ProtobufDataTrigger{
        device_id: device_id,
        interface_name: "*"
      }

      assert {:ok, {:device_and_any_interface, decoded_device_id}} ==
               Core.trigger_subject(:data_trigger, trigger)
    end

    test "returns {:device_and_interface, device_id, interface_id} when device and interface are specified" do
      device_id = DeviceGenerator.encoded_id() |> Enum.at(0)
      {:ok, decoded_device_id} = Device.decode_device_id(device_id, allow_extended_id: true)
      interface_id = CQLUtils.interface_id("com.example.Test", 1)

      trigger = %ProtobufDataTrigger{
        device_id: device_id,
        interface_name: "com.example.Test",
        interface_major: 1
      }

      assert {:ok, {:device_and_interface, decoded_device_id, interface_id}} ==
               Core.trigger_subject(:data_trigger, trigger)
    end
  end

  describe "pretty_device_event_type/1" do
    test "maps DEVICE_CONNECTED to :on_device_connection" do
      assert Core.pretty_device_event_type(:DEVICE_CONNECTED) ==
               :on_device_connection
    end

    test "maps DEVICE_DISCONNECTED to :on_device_disconnection" do
      assert Core.pretty_device_event_type(:DEVICE_DISCONNECTED) ==
               :on_device_disconnection
    end

    test "maps DEVICE_EMPTY_CACHE_RECEIVED to :on_empty_cache_received" do
      assert Core.pretty_device_event_type(:DEVICE_EMPTY_CACHE_RECEIVED) ==
               :on_empty_cache_received
    end

    test "maps DEVICE_ERROR to :on_device_error" do
      assert Core.pretty_device_event_type(:DEVICE_ERROR) ==
               :on_device_error
    end

    test "maps INCOMING_INTROSPECTION to :on_incoming_introspection" do
      assert Core.pretty_device_event_type(:INCOMING_INTROSPECTION) ==
               :on_incoming_introspection
    end

    test "maps INTERFACE_ADDED to :on_interface_added" do
      assert Core.pretty_device_event_type(:INTERFACE_ADDED) ==
               :on_interface_added
    end

    test "maps INTERFACE_REMOVED to :on_interface_removed" do
      assert Core.pretty_device_event_type(:INTERFACE_REMOVED) ==
               :on_interface_removed
    end

    test "maps INTERFACE_MINOR_UPDATED to :on_interface_minor_updated" do
      assert Core.pretty_device_event_type(:INTERFACE_MINOR_UPDATED) ==
               :on_interface_minor_updated
    end

    test "maps DEVICE_REGISTERED to :on_device_registered" do
      assert Core.pretty_device_event_type(:DEVICE_REGISTERED) ==
               :on_device_registered
    end

    test "maps DEVICE_DELETION_STARTED to :on_device_deletion_started" do
      assert Core.pretty_device_event_type(:DEVICE_DELETION_STARTED) ==
               :on_device_deletion_started
    end

    test "maps DEVICE_DELETION_FINISHED to :on_device_deletion_finished" do
      assert Core.pretty_device_event_type(:DEVICE_DELETION_FINISHED) ==
               :on_device_deletion_finished
    end
  end

  describe "load_trigger/4" do
    setup context do
      %{realm_name: realm_name} = context
      {:ok, realm_name: realm_name}
    end

    test "adds target under the correct device trigger key", %{realm_name: realm_name} do
      trigger = %ProtobufDeviceTrigger{
        device_event_type: :DEVICE_CONNECTED,
        device_id: nil,
        group_name: nil
      }

      target = %AMQPTriggerTarget{
        parent_trigger_id: UUID.uuid4(),
        simple_trigger_id: UUID.uuid4()
      }

      initial_state = %{
        device_triggers: %{},
        data_triggers: %{},
        trigger_id_to_policy_name: %{},
        interfaces: %{},
        interface_ids_to_name: %{}
      }

      assert {:ok, new_state} =
               Core.load_trigger(
                 realm_name,
                 {:device_trigger, trigger},
                 target,
                 initial_state
               )

      assert new_state.device_triggers[:on_device_connection] == [target]
    end

    test "appends multiple targets to the same device trigger key", %{realm_name: realm_name} do
      trigger = %ProtobufDeviceTrigger{
        device_event_type: :DEVICE_DISCONNECTED
      }

      target1 = %AMQPTriggerTarget{
        parent_trigger_id: UUID.uuid4(),
        simple_trigger_id: UUID.uuid4()
      }

      target2 = %AMQPTriggerTarget{
        parent_trigger_id: UUID.uuid4(),
        simple_trigger_id: UUID.uuid4()
      }

      state = %{
        device_triggers: %{},
        data_triggers: %{},
        trigger_id_to_policy_name: %{},
        interfaces: %{},
        interface_ids_to_name: %{}
      }

      {:ok, state} =
        Core.load_trigger(realm_name, {:device_trigger, trigger}, target1, state)

      {:ok, state} =
        Core.load_trigger(realm_name, {:device_trigger, trigger}, target2, state)

      assert state.device_triggers[:on_device_disconnection] == [target2, target1]
    end

    test "adds a data trigger with :any_interface and :any_endpoint", %{realm_name: realm_name} do
      trigger = %ProtobufDataTrigger{
        data_trigger_type: :INCOMING_DATA,
        interface_name: "*",
        device_id: nil,
        group_name: nil,
        match_path: "*"
      }

      target = %AMQPTriggerTarget{
        parent_trigger_id: UUID.uuid4(),
        simple_trigger_id: UUID.uuid4()
      }

      state = %{
        device_triggers: %{},
        data_triggers: %{},
        trigger_id_to_policy_name: %{},
        interfaces: %{},
        interface_ids_to_name: %{}
      }

      assert {:ok, new_state} =
               Core.load_trigger(
                 realm_name,
                 {:data_trigger, trigger},
                 target,
                 state
               )

      assert map_size(new_state.data_triggers) == 1

      {{event, interface, endpoint}, [data_trigger]} =
        Enum.at(new_state.data_triggers, 0)

      assert event == :on_incoming_data
      assert interface == :any_interface
      assert endpoint == :any_endpoint
      assert data_trigger.trigger_targets == [target]
    end

    test "merges targets for congruent data triggers", %{realm_name: realm_name} do
      trigger = %ProtobufDataTrigger{
        data_trigger_type: :VALUE_CHANGE,
        interface_name: "*",
        device_id: nil,
        group_name: nil,
        match_path: "*"
      }

      target1 = %AMQPTriggerTarget{
        parent_trigger_id: UUID.uuid4(),
        simple_trigger_id: UUID.uuid4()
      }

      target2 = %AMQPTriggerTarget{
        parent_trigger_id: UUID.uuid4(),
        simple_trigger_id: UUID.uuid4()
      }

      state = %{
        device_triggers: %{},
        data_triggers: %{},
        trigger_id_to_policy_name: %{},
        interfaces: %{},
        interface_ids_to_name: %{}
      }

      {:ok, state} =
        Core.load_trigger(realm_name, {:data_trigger, trigger}, target1, state)

      {:ok, state} =
        Core.load_trigger(realm_name, {:data_trigger, trigger}, target2, state)

      [data_trigger] =
        state.data_triggers[{:on_value_change, :any_interface, :any_endpoint}]

      assert Enum.sort(data_trigger.trigger_targets) ==
               Enum.sort([target1, target2])
    end
  end

  describe "valid_trigger_for_value?/3" do
    test "returns true when path matches and value operator is ANY" do
      trigger =
        data_trigger(
          path_match_tokens: ["foo"],
          value_match_operator: :ANY
        )

      assert Core.valid_trigger_for_value?(trigger, ["foo"], 42)
    end

    test "returns false when path does not match" do
      trigger =
        data_trigger(
          path_match_tokens: ["foo"],
          value_match_operator: :ANY
        )

      refute Core.valid_trigger_for_value?(trigger, ["bar"], 42)
    end

    test "returns true when wildcard path token matches" do
      trigger =
        data_trigger(
          path_match_tokens: [""],
          value_match_operator: :ANY
        )

      assert Core.valid_trigger_for_value?(trigger, ["anything"], 42)
    end

    test "returns true for :any_endpoint" do
      trigger =
        data_trigger(
          path_match_tokens: :any_endpoint,
          value_match_operator: :ANY
        )

      assert Core.valid_trigger_for_value?(trigger, ["foo", "bar"], 42)
    end

    test "returns true when value matches EQUAL operator" do
      trigger =
        data_trigger(
          path_match_tokens: ["foo"],
          value_match_operator: :EQUAL_TO,
          known_value: 10
        )

      assert Core.valid_trigger_for_value?(trigger, ["foo"], 10)
    end

    test "returns false when value does not match EQUAL operator" do
      trigger =
        data_trigger(
          path_match_tokens: ["foo"],
          value_match_operator: :EQUAL_TO,
          known_value: 10
        )

      refute Core.valid_trigger_for_value?(trigger, ["foo"], 11)
    end

    test "returns false when path matches but value does not" do
      trigger =
        data_trigger(
          path_match_tokens: ["foo"],
          value_match_operator: :LESS_THAN,
          known_value: 5
        )

      refute Core.valid_trigger_for_value?(trigger, ["foo"], 10)
    end
  end

  describe "deserialize_simple_trigger/1" do
    setup context do
      %{realm_name: realm_name} = context
      {:ok, realm_name: realm_name}
    end

    test "deserializes trigger data and target and injects ids", %{realm_name: realm_name} do
      simple_trigger = generate_device_trigger(realm_name)

      {trigger_data, trigger_target} =
        Core.deserialize_simple_trigger(simple_trigger)

      assert {:device_trigger, %ProtobufDeviceTrigger{}} = trigger_data
      assert %AMQPTriggerTarget{} = trigger_target
      assert trigger_target.simple_trigger_id == simple_trigger.simple_trigger_id
      assert trigger_target.parent_trigger_id == simple_trigger.parent_trigger_id
    end
  end

  defp data_trigger(opts) do
    struct!(
      DataTriggerWithTargets,
      Keyword.merge(
        [
          path_match_tokens: ["foo"],
          value_match_operator: :ANY,
          known_value: nil,
          trigger_targets: []
        ],
        opts
      )
    )
  end
end
