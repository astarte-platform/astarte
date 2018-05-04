#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.DataUpdaterPlant.TriggersHandler do
  @moduledoc """
  This module handles the triggers by generating the events requested
  by the Trigger targets
  """

  use Astarte.Core.Triggers.SimpleEvents

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.DataUpdaterPlant.AMQPEventsProducer

  def device_connected(targets, realm, device_id, ip_address) when is_list(targets) do
    execute_all_ok(targets, fn target ->
      device_connected(target, realm, device_id, ip_address) == :ok
    end)
  end

  def device_connected(target, realm, device_id, ip_address) do
    %DeviceConnectedEvent{device_ip_address: ip_address}
    |> make_simple_event(
      :device_connected_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  def device_disconnected(targets, realm, device_id) when is_list(targets) do
    execute_all_ok(targets, fn target ->
      device_disconnected(target, realm, device_id) == :ok
    end)
  end

  def device_disconnected(target, realm, device_id) do
    %DeviceDisconnectedEvent{}
    |> make_simple_event(
      :device_disconnected_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  def incoming_data(targets, realm, device_id, interface, path, bson_value)
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      incoming_data(target, realm, device_id, interface, path, bson_value) == :ok
    end)
  end

  def incoming_data(target, realm, device_id, interface, path, bson_value) do
    %IncomingDataEvent{interface: interface, path: path, bson_value: bson_value}
    |> make_simple_event(
      :incoming_data_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  def incoming_introspection(targets, realm, device_id, introspection) when is_list(targets) do
    execute_all_ok(targets, fn target ->
      incoming_introspection(target, realm, device_id, introspection) == :ok
    end)
  end

  def incoming_introspection(target, realm, device_id, introspection) do
    %IncomingIntrospectionEvent{introspection: introspection}
    |> make_simple_event(
      :incoming_introspection_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  def interface_added(targets, realm, device_id, interface, major_version, minor_version)
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      interface_added(target, realm, device_id, interface, major_version, minor_version) == :ok
    end)
  end

  def interface_added(target, realm, device_id, interface, major_version, minor_version) do
    %InterfaceAddedEvent{
      interface: interface,
      major_version: major_version,
      minor_version: minor_version
    }
    |> make_simple_event(
      :interface_added_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  def interface_minor_updated(
        targets,
        realm,
        device_id,
        interface,
        major_version,
        old_minor,
        new_minor
      )
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      interface_minor_updated(
        target,
        realm,
        device_id,
        interface,
        major_version,
        old_minor,
        new_minor
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
        new_minor
      ) do
    %InterfaceMinorUpdatedEvent{
      interface: interface,
      major_version: major_version,
      old_minor_version: old_minor,
      new_minor_version: new_minor
    }
    |> make_simple_event(
      :interface_minor_updated_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  def interface_removed(targets, realm, device_id, interface, major_version)
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      interface_removed(target, realm, device_id, interface, major_version) == :ok
    end)
  end

  def interface_removed(target, realm, device_id, interface, major_version) do
    %InterfaceRemovedEvent{interface: interface, major_version: major_version}
    |> make_simple_event(
      :interface_removed_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  def path_created(targets, realm, device_id, interface, path, bson_value)
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      path_created(target, realm, device_id, interface, path, bson_value) == :ok
    end)
  end

  def path_created(target, realm, device_id, interface, path, bson_value) do
    %PathCreatedEvent{interface: interface, path: path, bson_value: bson_value}
    |> make_simple_event(
      :path_created_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  def path_removed(targets, realm, device_id, interface, path) when is_list(targets) do
    execute_all_ok(targets, fn target ->
      path_removed(target, realm, device_id, interface, path) == :ok
    end)
  end

  def path_removed(target, realm, device_id, interface, path) do
    %PathRemovedEvent{interface: interface, path: path}
    |> make_simple_event(
      :path_removed_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  def value_change(targets, realm, device_id, interface, path, old_bson_value, new_bson_value)
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      value_change(target, realm, device_id, interface, path, old_bson_value, new_bson_value) ==
        :ok
    end)
  end

  def value_change(target, realm, device_id, interface, path, old_bson_value, new_bson_value) do
    %ValueChangeEvent{
      interface: interface,
      path: path,
      old_bson_value: old_bson_value,
      new_bson_value: new_bson_value
    }
    |> make_simple_event(
      :value_change_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  def value_change_applied(
        targets,
        realm,
        device_id,
        interface,
        path,
        old_bson_value,
        new_bson_value
      )
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      value_change_applied(
        target,
        realm,
        device_id,
        interface,
        path,
        old_bson_value,
        new_bson_value
      ) == :ok
    end)
  end

  def value_change_applied(
        target,
        realm,
        device_id,
        interface,
        path,
        old_bson_value,
        new_bson_value
      ) do
    %ValueChangeAppliedEvent{
      interface: interface,
      path: path,
      old_bson_value: old_bson_value,
      new_bson_value: new_bson_value
    }
    |> make_simple_event(
      :value_change_applied_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id
    )
    |> dispatch_event(target)
  end

  defp make_simple_event(
         event,
         event_type,
         simple_trigger_id,
         parent_trigger_id,
         realm,
         device_id
       ) do
    %SimpleEvent{
      simple_trigger_id: simple_trigger_id,
      parent_trigger_id: parent_trigger_id,
      realm: realm,
      device_id: device_id,
      event: {event_type, event}
    }
  end

  defp execute_all_ok(items, fun) do
    if Enum.all?(items, fun) do
      :ok
    else
      :error
    end
  end

  defp dispatch_event(simple_event = %SimpleEvent{}, %AMQPTriggerTarget{
         routing_key: routing_key,
         static_headers: static_headers
       }) do
    {event_type, _event_struct} = simple_event.event

    simple_trigger_id_str =
      simple_event.simple_trigger_id
      |> :uuid.uuid_to_string()
      |> to_string()

    parent_trigger_id_str =
      simple_event.parent_trigger_id
      |> :uuid.uuid_to_string()
      |> to_string()

    headers = [
      {"x_astarte_realm", simple_event.realm},
      {"x_astarte_device_id", simple_event.device_id},
      {"x_astarte_simple_trigger_id", simple_trigger_id_str},
      {"x_astarte_parent_trigger_id", parent_trigger_id_str},
      {"x_astarte_event_type", to_string(event_type)}
      | static_headers
    ]

    SimpleEvent.encode(simple_event)
    |> AMQPEventsProducer.publish(routing_key, headers)
  end
end
