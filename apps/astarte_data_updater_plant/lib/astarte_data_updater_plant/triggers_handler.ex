#
# This file is part of Astarte.
#
# Copyright 2017-2020 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlant.TriggersHandler do
  @moduledoc """
  This module handles the triggers by generating the events requested
  by the Trigger targets
  """

  alias Astarte.Core.Triggers.SimpleEvents.{
    DeviceConnectedEvent,
    DeviceDisconnectedEvent,
    DeviceErrorEvent,
    IncomingDataEvent,
    IncomingIntrospectionEvent,
    InterfaceAddedEvent,
    InterfaceMinorUpdatedEvent,
    InterfaceRemovedEvent,
    InterfaceVersion,
    PathCreatedEvent,
    PathRemovedEvent,
    ValueChangeAppliedEvent,
    ValueChangeEvent
  }

  alias Astarte.Core.Device
  alias Astarte.Core.CQLUtils
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.Events.Triggers
  alias Astarte.Events.TriggersHandler

  require Logger

  defdelegate register_target(realm_name, trigger_target), to: TriggersHandler

  def device_connected(realm, device_id, groups, ip_address, timestamp) do
    event = %DeviceConnectedEvent{device_ip_address: ip_address}
    hw_id = Device.encode_device_id(device_id)

    Triggers.find_device_trigger_targets(realm, device_id, groups, :on_device_connection)
    |> execute_all_ok(fn {target, policy} ->
      dispatch_event_with_telemetry(
        event,
        :device_connected_event,
        target,
        realm,
        hw_id,
        timestamp,
        policy
      )
    end)
  end

  def device_disconnected(realm, device_id, groups, timestamp) do
    event = %DeviceDisconnectedEvent{}
    hw_id = Device.encode_device_id(device_id)

    Triggers.find_device_trigger_targets(realm, device_id, groups, :on_device_disconnection)
    |> execute_all_ok(fn {target, policy} ->
      dispatch_event_with_telemetry(
        event,
        :device_disconnected_event,
        target,
        realm,
        hw_id,
        timestamp,
        policy
      )
    end)
  end

  def device_error(
        realm,
        device_id,
        groups,
        error_name,
        error_metadata,
        timestamp
      ) do
    event = %DeviceErrorEvent{error_name: error_name, metadata: error_metadata}
    hw_id = Device.encode_device_id(device_id)

    Triggers.find_device_trigger_targets(realm, device_id, groups, :on_device_error)
    |> execute_all_ok(fn {target, policy} ->
      dispatch_event_with_telemetry(
        event,
        :device_error_event,
        target,
        realm,
        hw_id,
        timestamp,
        policy
      )
    end)
  end

  def incoming_data(context) do
    %{
      hardware_id: hw_id,
      interface_id: interface_id,
      interface: interface_name,
      endpoint_id: endpoint_id,
      value_timestamp: timestamp,
      state: state,
      value: value,
      payload: bson_value,
      path: path
    } = context

    %{realm: realm, device_id: device_id, groups: groups} = state

    event = %IncomingDataEvent{interface: interface_name, path: path, bson_value: bson_value}

    Triggers.find_all_data_trigger_targets(
      realm,
      device_id,
      groups,
      :on_incoming_data,
      interface_id,
      endpoint_id,
      path,
      value,
      Map.from_struct(state)
    )
    |> execute_all_ok(fn {target, policy} ->
      dispatch_event_with_telemetry(
        event,
        :incoming_data_event,
        target,
        realm,
        hw_id,
        timestamp,
        policy
      )
    end)
  end

  def incoming_introspection(
        realm,
        device_id,
        groups,
        introspection_string,
        timestamp
      ) do
    hw_id = Device.encode_device_id(device_id)
    event = incoming_introspection_event(introspection_string)

    Triggers.find_device_trigger_targets(realm, device_id, groups, :on_incoming_introspection)
    |> execute_all_ok(fn {target, policy} ->
      dispatch_event_with_telemetry(
        event,
        :incoming_introspection_event,
        target,
        realm,
        hw_id,
        timestamp,
        policy
      )
    end)
  end

  @spec interface_added(
          String.t(),
          Astarte.DataAccess.UUID.t(),
          [String.t()],
          String.t(),
          non_neg_integer(),
          pos_integer(),
          integer()
        ) :: :ok
  def interface_added(
        realm,
        device_id,
        groups,
        interface,
        major_version,
        minor_version,
        timestamp
      ) do
    interface_id = CQLUtils.interface_id(interface, major_version)
    hw_id = Device.encode_device_id(device_id)

    event =
      %InterfaceAddedEvent{
        interface: interface,
        major_version: major_version,
        minor_version: minor_version
      }

    Triggers.find_interface_event_device_trigger_targets(
      realm,
      device_id,
      groups,
      :on_interface_added,
      interface_id
    )
    |> execute_all_ok(fn {target, policy} ->
      dispatch_event_with_telemetry(
        event,
        :interface_added_event,
        target,
        realm,
        hw_id,
        timestamp,
        policy
      )
    end)
  end

  def interface_minor_updated(
        targets,
        realm,
        device_id,
        interface,
        major_version,
        old_minor,
        new_minor,
        timestamp
      )
      when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      interface_minor_updated(
        target,
        realm,
        device_id,
        interface,
        major_version,
        old_minor,
        new_minor,
        timestamp,
        policy
      ) == :ok
    end)
  end

  def interface_minor_updated(
        target,
        realm,
        device_id,
        interface,
        major_version,
        old_minor,
        new_minor,
        timestamp,
        policy
      ) do
    %InterfaceMinorUpdatedEvent{
      interface: interface,
      major_version: major_version,
      old_minor_version: old_minor,
      new_minor_version: new_minor
    }
    |> dispatch_event_with_telemetry(
      :interface_minor_updated_event,
      target,
      realm,
      device_id,
      timestamp,
      policy
    )
  end

  def interface_removed(targets, realm, device_id, interface, major_version, timestamp)
      when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      interface_removed(target, realm, device_id, interface, major_version, timestamp, policy) ==
        :ok
    end)
  end

  def interface_removed(
        target,
        realm,
        device_id,
        interface,
        major_version,
        timestamp,
        policy
      ) do
    %InterfaceRemovedEvent{interface: interface, major_version: major_version}
    |> dispatch_event_with_telemetry(
      :interface_removed_event,
      target,
      realm,
      device_id,
      timestamp,
      policy
    )
  end

  def path_created(context, bson_value) do
    %{
      hardware_id: hw_id,
      interface: interface,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      value_timestamp: timestamp,
      state: state,
      value: value,
      path: path
    } = context

    %{realm: realm, device_id: device_id, groups: groups} = state

    event = %PathCreatedEvent{interface: interface, path: path, bson_value: bson_value}

    Triggers.find_all_data_trigger_targets(
      realm,
      device_id,
      groups,
      :on_path_created,
      interface_id,
      endpoint_id,
      path,
      value,
      Map.from_struct(state)
    )
    |> execute_all_ok(fn {target, policy} ->
      dispatch_event_with_telemetry(
        event,
        :path_created_event,
        target,
        realm,
        hw_id,
        timestamp,
        policy
      )
    end)
  end

  def path_removed(context) do
    %{
      hardware_id: hw_id,
      interface: interface,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      value_timestamp: timestamp,
      state: state,
      path: path
    } = context

    %{realm: realm, device_id: device_id, groups: groups} = state

    event = %PathRemovedEvent{interface: interface, path: path}

    Triggers.find_all_data_trigger_targets(
      realm,
      device_id,
      groups,
      :on_path_removed,
      interface_id,
      endpoint_id,
      path,
      Map.from_struct(state)
    )
    |> execute_all_ok(fn {target, policy} ->
      dispatch_event_with_telemetry(
        event,
        :path_removed_event,
        target,
        realm,
        hw_id,
        timestamp,
        policy
      )
    end)
  end

  def value_change(
        context,
        old_bson_value,
        new_bson_value
      ) do
    %{
      hardware_id: hw_id,
      interface: interface,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      value_timestamp: timestamp,
      state: state,
      value: value,
      path: path
    } = context

    %{realm: realm, device_id: device_id, groups: groups} = state

    event = %ValueChangeEvent{
      interface: interface,
      path: path,
      old_bson_value: old_bson_value,
      new_bson_value: new_bson_value
    }

    Triggers.find_all_data_trigger_targets(
      realm,
      device_id,
      groups,
      :on_value_change,
      interface_id,
      endpoint_id,
      path,
      value,
      Map.from_struct(state)
    )
    |> execute_all_ok(fn {target, policy} ->
      dispatch_event_with_telemetry(
        event,
        :value_change_event,
        target,
        realm,
        hw_id,
        timestamp,
        policy
      )
    end)
  end

  def value_change_applied(
        context,
        old_bson_value,
        new_bson_value
      ) do
    %{
      hardware_id: hw_id,
      interface: interface,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      value_timestamp: timestamp,
      state: state,
      value: value,
      path: path
    } = context

    %{realm: realm, device_id: device_id, groups: groups} = state

    event = %ValueChangeAppliedEvent{
      interface: interface,
      path: path,
      old_bson_value: old_bson_value,
      new_bson_value: new_bson_value
    }

    Triggers.find_all_data_trigger_targets(
      realm,
      device_id,
      groups,
      :on_value_change_applied,
      interface_id,
      endpoint_id,
      path,
      value,
      Map.from_struct(state)
    )
    |> execute_all_ok(fn {target, policy} ->
      dispatch_event_with_telemetry(
        event,
        :value_change_applied_event,
        target,
        realm,
        hw_id,
        timestamp,
        policy
      )
    end)
  end

  defp incoming_introspection_event(introspection_string) do
    case Config.generate_legacy_incoming_introspection_events!() do
      true ->
        %IncomingIntrospectionEvent{introspection: introspection_string}

      false ->
        introspection_map = introspection_string_to_introspection_proto_map!(introspection_string)
        %IncomingIntrospectionEvent{introspection_map: introspection_map}
    end
  end

  defp introspection_string_to_introspection_proto_map!(introspection_string) do
    # The string format is defined in Astarte MQTTv1,
    # so we want to crash here if something goes wrong
    introspection_string_entries = String.split(introspection_string, ";")

    Enum.reduce(introspection_string_entries, %{}, fn entry, acc ->
      [name, major, minor] = String.split(entry, ":")
      {major_value, ""} = Integer.parse(major)
      {minor_value, ""} = Integer.parse(minor)

      Map.put_new(acc, name, %InterfaceVersion{
        major: major_value,
        minor: minor_value
      })
    end)
  end

  defp execute_all_ok(items, fun) do
    if Enum.all?(items, fun) do
      :ok
    else
      :error
    end
  end

  defp dispatch_event_with_telemetry(
         event,
         event_type,
         target,
         realm,
         device_id,
         timestamp,
         policy
       ) do
    result =
      TriggersHandler.dispatch_event(
        event,
        event_type,
        target,
        realm,
        device_id,
        timestamp,
        policy
      )

    :telemetry.execute(
      [:astarte, :data_updater_plant, :triggers_handler, :published_event],
      %{},
      %{
        realm: realm,
        event_type: to_string(event_type)
      }
    )

    result
  end
end
