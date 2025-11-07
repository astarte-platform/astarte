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

  def device_disconnected(targets, realm, device_id, timestamp) when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      device_disconnected(target, realm, device_id, timestamp, policy) == :ok
    end)
  end

  def device_disconnected(target, realm, device_id, timestamp, policy) do
    %DeviceDisconnectedEvent{}
    |> dispatch_event_with_telemetry(
      :device_disconnected_event,
      target,
      realm,
      device_id,
      timestamp,
      policy
    )
  end

  def device_error(targets, realm, device_id, error_name, error_metadata, timestamp)
      when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      device_error(target, realm, device_id, error_name, error_metadata, timestamp, policy) == :ok
    end)
  end

  def device_error(
        target,
        realm,
        device_id,
        error_name,
        error_metadata,
        timestamp,
        policy
      ) do
    metadata_kw = Enum.into(error_metadata, [])

    %DeviceErrorEvent{error_name: error_name, metadata: metadata_kw}
    |> dispatch_event_with_telemetry(
      :device_error_event,
      target,
      realm,
      device_id,
      timestamp,
      policy
    )
  end

  def incoming_data(
        realm,
        device_id,
        groups,
        interface_name,
        interface_id,
        endpoint_id,
        path,
        value,
        bson_value,
        timestamp,
        state
      ) do
    event = %IncomingDataEvent{interface: interface_name, path: path, bson_value: bson_value}
    hw_id = Device.encode_device_id(device_id)

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

  def incoming_introspection(targets, realm, device_id, introspection, timestamp)
      when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      incoming_introspection(target, realm, device_id, introspection, timestamp, policy) == :ok
    end)
  end

  def incoming_introspection(
        target,
        realm,
        device_id,
        introspection_string,
        timestamp,
        policy
      ) do
    incoming_introspection_event =
      unless Config.generate_legacy_incoming_introspection_events!() do
        introspection_map = introspection_string_to_introspection_proto_map!(introspection_string)
        %IncomingIntrospectionEvent{introspection_map: introspection_map}
      else
        %IncomingIntrospectionEvent{introspection: introspection_string}
      end

    incoming_introspection_event
    |> dispatch_event_with_telemetry(
      :incoming_introspection_event,
      target,
      realm,
      device_id,
      timestamp,
      policy
    )
  end

  def interface_added(
        targets,
        realm,
        device_id,
        interface,
        major_version,
        minor_version,
        timestamp
      )
      when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      interface_added(
        target,
        realm,
        device_id,
        interface,
        major_version,
        minor_version,
        timestamp,
        policy
      ) == :ok
    end)
  end

  @spec interface_added(
          Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget.t(),
          any,
          any,
          any,
          any,
          any,
          any,
          any
        ) :: :ok
  def interface_added(
        target,
        realm,
        device_id,
        interface,
        major_version,
        minor_version,
        timestamp,
        policy
      ) do
    %InterfaceAddedEvent{
      interface: interface,
      major_version: major_version,
      minor_version: minor_version
    }
    |> dispatch_event_with_telemetry(
      :interface_added_event,
      target,
      realm,
      device_id,
      timestamp,
      policy
    )
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

  def path_created(
        realm,
        device_id,
        groups,
        interface_id,
        endpoint_id,
        interface,
        path,
        value,
        bson_value,
        timestamp,
        state
      ) do
    event = %PathCreatedEvent{interface: interface, path: path, bson_value: bson_value}
    hw_id = Device.encode_device_id(device_id)

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

  def path_removed(
        realm,
        device_id,
        groups,
        interface_id,
        endpoint_id,
        interface,
        path,
        timestamp,
        state
      ) do
    event = %PathRemovedEvent{interface: interface, path: path}
    hw_id = Device.encode_device_id(device_id)

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
        realm,
        device_id,
        groups,
        interface_id,
        endpoint_id,
        interface,
        path,
        new_value,
        old_bson_value,
        new_bson_value,
        timestamp,
        state
      ) do
    hw_id = Device.encode_device_id(device_id)

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
      new_value,
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
        realm,
        device_id,
        groups,
        interface_id,
        endpoint_id,
        interface,
        path,
        new_value,
        old_bson_value,
        new_bson_value,
        timestamp,
        state
      ) do
    event = %ValueChangeAppliedEvent{
      interface: interface,
      path: path,
      old_bson_value: old_bson_value,
      new_bson_value: new_bson_value
    }

    hw_id = Device.encode_device_id(device_id)

    Triggers.find_all_data_trigger_targets(
      realm,
      device_id,
      groups,
      :on_value_change_applied,
      interface_id,
      endpoint_id,
      path,
      new_value,
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
