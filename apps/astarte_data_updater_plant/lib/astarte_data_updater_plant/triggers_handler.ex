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

  alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent
  alias Astarte.Core.Triggers.SimpleEvents.PathCreatedEvent
  alias Astarte.Core.Triggers.SimpleEvents.PathRemovedEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleEvents.ValueChangeAppliedEvent
  alias Astarte.Core.Triggers.SimpleEvents.ValueChangeEvent
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.DataUpdaterPlant.AMQPEventsProducer

  def on_incoming_data(targets, realm, device_id, interface, path, bson_value) when is_list(targets) do
    Enum.each(targets, fn target ->
      on_incoming_data(target, realm, device_id, interface, path, bson_value)
    end)
  end

  def on_incoming_data(target, realm, device_id, interface, path, bson_value) do
    %IncomingDataEvent{interface: interface, path: path, bson_value: bson_value}
    |> make_simple_event(:incoming_data_event, target.simple_trigger_id, target.parent_trigger_id, realm, device_id)
    |> dispatch_event(target)
  end

  def on_path_created(targets, realm, device_id, interface, path, bson_value) when is_list(targets) do
    Enum.each(targets, fn target ->
      on_path_created(target, realm, device_id, interface, path, bson_value)
    end)
  end

  def on_path_created(target, realm, device_id, interface, path, bson_value) do
    %PathCreatedEvent{interface: interface, path: path, bson_value: bson_value}
    |> make_simple_event(:path_created_event, target.simple_trigger_id, target.parent_trigger_id, realm, device_id)
    |> dispatch_event(target)
  end

  def on_path_removed(targets, realm, device_id, interface, path) when is_list(targets) do
    Enum.each(targets, fn target ->
      on_path_removed(target, realm, device_id, interface, path)
    end)
  end

  def on_path_removed(target, realm, device_id, interface, path) do
    %PathRemovedEvent{interface: interface, path: path}
    |> make_simple_event(:path_removed_event, target.simple_trigger_id, target.parent_trigger_id, realm, device_id)
    |> dispatch_event(target)
  end

  def on_value_change(targets, realm, device_id, interface, path, old_bson_value, new_bson_value) when is_list(targets) do
    Enum.each(targets, fn target ->
      on_value_change(target, realm, device_id, interface, path, old_bson_value, new_bson_value)
    end)
  end

  def on_value_change(target, realm, device_id, interface, path, old_bson_value, new_bson_value) do
    %ValueChangeEvent{interface: interface, path: path, old_bson_value: old_bson_value, new_bson_value: new_bson_value}
    |> make_simple_event(:value_change_event, target.simple_trigger_id, target.parent_trigger_id, realm, device_id)
    |> dispatch_event(target)
  end

  def on_value_change_applied(targets, realm, device_id, interface, path, old_bson_value, new_bson_value) when is_list(targets) do
    Enum.each(targets, fn target ->
      on_value_change_applied(target, realm, device_id, interface, path, old_bson_value, new_bson_value)
    end)
  end

  def on_value_change_applied(target, realm, device_id, interface, path, old_bson_value, new_bson_value) do
    %ValueChangeAppliedEvent{interface: interface, path: path, old_bson_value: old_bson_value, new_bson_value: new_bson_value}
    |> make_simple_event(:value_change_applied_event, target.simple_trigger_id, target.parent_trigger_id, realm, device_id)
    |> dispatch_event(target)
  end

  defp make_simple_event(event, event_type, simple_trigger_id, parent_trigger_id, realm, device_id) do
    %SimpleEvent{
      simple_trigger_id: simple_trigger_id,
      parent_trigger_id: parent_trigger_id,
      realm: realm,
      device_id: device_id,
      event: {event_type, event}
    }
  end

  defp dispatch_event(simple_event = %SimpleEvent{}, %AMQPTriggerTarget{routing_key: routing_key, static_headers: static_headers}) do
    {event_type, _event_struct} = simple_event.event

    headers =
      [{"x_astarte_realm", simple_event.realm},
       {"x_astarte_device_id", simple_event.device_id},
       {"x_astarte_event_type", to_string(event_type)}
       | static_headers]

    SimpleEvent.encode(simple_event)
    |> AMQPEventsProducer.publish(routing_key, headers)
  end
end
