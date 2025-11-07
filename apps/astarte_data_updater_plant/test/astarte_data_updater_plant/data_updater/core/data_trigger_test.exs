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
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Trigger
  use Astarte.Cases.Device
  use ExUnitProperties

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.TriggersHandler

  import Astarte.Helpers.DataUpdater

  @moduletag :data_updater

  setup_all :populate_interfaces

  setup_all %{realm_name: realm_name, device: device} do
    setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state}
  end

  defp mock_trigger_target(routing_key) do
    %AMQPTriggerTarget{
      parent_trigger_id: :uuid.get_v4(),
      simple_trigger_id: :uuid.get_v4(),
      static_headers: [],
      routing_key: routing_key
    }
  end

  defp install_volatile_trigger(state, data_trigger) do
    id = System.unique_integer()
    test_process = self()
    ref = {:event_dispatched, id}
    trigger_target = mock_trigger_target("target#{id}")
    deserialized_simple_trigger = {{:data_trigger, data_trigger}, trigger_target}

    Astarte.Events.TriggersHandler
    |> Mimic.stub(:dispatch_event, fn _event,
                                      _event_ype,
                                      ^trigger_target,
                                      _realm,
                                      _hw_id,
                                      _timestamp,
                                      _policy ->
      send(test_process, ref)
    end)

    Astarte.Events.Triggers.install_volatile_trigger(
      state.realm,
      deserialized_simple_trigger,
      state
    )

    ref
  end

  def add_interface(state, interface_name, interface_major, path, value_type) do
    interface_id = CQLUtils.interface_id(interface_name, interface_major)
    endpoint_id = CQLUtils.endpoint_id(interface_name, interface_major, path)

    mapping = %Mapping{
      endpoint: path,
      value_type: value_type,
      endpoint_id: endpoint_id,
      interface_id: interface_id
    }

    {:ok, automaton} = EndpointsAutomaton.build([mapping])
    {transitions, accepting_states_with_endpoints} = automaton

    accepting_states =
      replace_automaton_acceptings_with_ids(
        accepting_states_with_endpoints,
        interface_name,
        interface_major
      )

    automaton = {transitions, accepting_states}

    descriptor = %InterfaceDescriptor{
      name: interface_name,
      major_version: interface_major,
      minor_version: 1,
      type: :datastream,
      ownership: :device,
      aggregation: :individual,
      interface_id: interface_id,
      storage: "individual_datastreams",
      storage_type: :multi_interface_individual_datastream_dbtable,
      automaton: automaton
    }

    state = put_in(state.interface_ids_to_name[interface_id], interface_name)
    state = put_in(state.interfaces[interface_name], descriptor)
    state = put_in(state.introspection[interface_name], interface_major)

    state
  end

  defp build_context(state, interface_name, interface_major, value_type, path, value) do
    hw_id = Device.encode_device_id(state.device_id)
    state = add_interface(state, interface_name, interface_major, path, value_type)

    context = %{
      hardware_id: hw_id,
      interface: interface_name,
      path: path,
      interface_id: CQLUtils.interface_id(interface_name, interface_major),
      endpoint_id: CQLUtils.endpoint_id(interface_name, interface_major, path),
      payload: Cyanide.encode!(%{"value" => value}),
      value: value,
      value_timestamp: 1_600_000_000_000_000,
      state: state
    }

    {state, context}
  end

  defp replace_automaton_acceptings_with_ids(accepting_states, interface_name, major) do
    Map.new(accepting_states, fn {state_index, endpoint} ->
      endpoint_id = CQLUtils.endpoint_id(interface_name, major, endpoint)
      {state_index, endpoint_id}
    end)
  end

  describe "execute_incoming_data_triggers/9" do
    test "doesn't execute triggers for incoming data events with empty triggers", context do
      %{state: state} = context
      {_state, context} = build_context(state, "test.interface", 1, :integer, "/test/path", 42)

      Mimic.reject(&Astarte.Events.TriggersHandler.dispatch_event/7)

      assert :ok == TriggersHandler.incoming_data(context)
    end

    test "executes global triggers for any interface/endpoint", context do
      %{state: state} = context
      interface_name = "com.example.Sensors"
      interface_major = 1
      path = "/sensors/temperature"
      value = 42

      {state, context} =
        build_context(state, interface_name, interface_major, :integer, path, value)

      ref =
        install_volatile_trigger(state, %DataTrigger{
          interface_name: "*",
          data_trigger_type: :INCOMING_DATA,
          match_path: "/*",
          value_match_operator: :LESS_THAN,
          known_value: Cyanide.encode!(%{v: 50})
        })

      assert :ok == TriggersHandler.incoming_data(context)

      assert_receive ^ref
    end

    test "executes interface-specific triggers", context do
      %{
        state: state
      } = context

      interface_name = "com.example.Sensors"
      interface_major = 1
      path = "/sensors/temperature"
      value = 42

      {state, context} =
        build_context(state, interface_name, interface_major, :integer, path, value)

      ref =
        install_volatile_trigger(state, %DataTrigger{
          interface_name: interface_name,
          interface_major: interface_major,
          data_trigger_type: :INCOMING_DATA,
          match_path: "/*",
          value_match_operator: :LESS_THAN,
          known_value: Cyanide.encode!(%{v: 50})
        })

      assert :ok == TriggersHandler.incoming_data(context)

      assert_receive ^ref
    end

    test "executes endpoint-specific triggers", context do
      %{state: state} = context
      interface_name = "com.example.Sensors"
      interface_major = 1
      path = "/sensors/temperature"
      value = 42

      {state, context} =
        build_context(state, interface_name, interface_major, :integer, path, value)

      ref =
        install_volatile_trigger(state, %DataTrigger{
          interface_name: interface_name,
          interface_major: interface_major,
          data_trigger_type: :INCOMING_DATA,
          match_path: "/sensors/temperature",
          value_match_operator: :LESS_THAN,
          known_value: Cyanide.encode!(%{v: 50})
        })

      assert :ok == TriggersHandler.incoming_data(context)

      assert_receive ^ref
    end

    test "does not execute triggers when value doesn't match condition", context do
      %{state: state} = context

      interface_name = "com.example.Sensors"
      interface_major = 1
      path = "/sensors/temperature"
      value = 60

      {state, context} =
        build_context(state, interface_name, interface_major, :integer, path, value)

      install_volatile_trigger(state, %DataTrigger{
        interface_name: interface_name,
        interface_major: interface_major,
        data_trigger_type: :INCOMING_DATA,
        match_path: "/sensors/temperature",
        value_match_operator: :LESS_THAN,
        known_value: Cyanide.encode!(%{v: 50})
      })

      Mimic.reject(&Astarte.Events.TriggersHandler.dispatch_event/7)

      assert :ok == TriggersHandler.incoming_data(context)
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

      hw_id = Device.encode_device_id(device.device_id)

      context = %{
        interface: "iface",
        interface_id: interface_id,
        endpoint_id: endpoint_id,
        hardware_id: hw_id,
        path: "/path",
        value: value,
        value_timestamp: timestamp,
        payload: payload,
        state: state
      }

      assert :ok == TriggersHandler.incoming_data(context)
    end
  end
end
