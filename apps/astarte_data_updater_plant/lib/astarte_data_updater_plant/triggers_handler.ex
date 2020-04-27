#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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
  use Bitwise, only_operators: true
  require Logger
  alias Astarte.DataUpdaterPlant.Config

  @moduledoc """
  This module handles the triggers by generating the events requested
  by the Trigger targets
  """

  @max_backoff_exponent 10

  use Astarte.Core.Triggers.SimpleEvents

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.DataUpdaterPlant.AMQPEventsProducer

  def device_connected(targets, realm, device_id, ip_address, timestamp) when is_list(targets) do
    execute_all_ok(targets, fn target ->
      device_connected(target, realm, device_id, ip_address, timestamp) == :ok
    end)
  end

  def device_connected(target, realm, device_id, ip_address, timestamp) do
    %DeviceConnectedEvent{device_ip_address: ip_address}
    |> make_simple_event(
      :device_connected_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target)
  end

  def device_disconnected(targets, realm, device_id, timestamp) when is_list(targets) do
    execute_all_ok(targets, fn target ->
      device_disconnected(target, realm, device_id, timestamp) == :ok
    end)
  end

  def device_disconnected(target, realm, device_id, timestamp) do
    %DeviceDisconnectedEvent{}
    |> make_simple_event(
      :device_disconnected_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target)
  end

  def incoming_data(targets, realm, device_id, interface, path, bson_value, timestamp)
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      incoming_data(target, realm, device_id, interface, path, bson_value, timestamp) == :ok
    end)
  end

  def incoming_data(target, realm, device_id, interface, path, bson_value, timestamp) do
    %IncomingDataEvent{interface: interface, path: path, bson_value: bson_value}
    |> make_simple_event(
      :incoming_data_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target)
  end

  def incoming_introspection(targets, realm, device_id, introspection, timestamp)
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      incoming_introspection(target, realm, device_id, introspection, timestamp) == :ok
    end)
  end

  def incoming_introspection(target, realm, device_id, introspection, timestamp) do
    %IncomingIntrospectionEvent{introspection: introspection}
    |> make_simple_event(
      :incoming_introspection_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target)
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
    execute_all_ok(targets, fn target ->
      interface_added(
        target,
        realm,
        device_id,
        interface,
        major_version,
        minor_version,
        timestamp
      ) == :ok
    end)
  end

  def interface_added(
        target,
        realm,
        device_id,
        interface,
        major_version,
        minor_version,
        timestamp
      ) do
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
      device_id,
      timestamp
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
        new_minor,
        timestamp
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
        new_minor,
        timestamp
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
        timestamp
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
      device_id,
      timestamp
    )
    |> dispatch_event(target)
  end

  def interface_removed(targets, realm, device_id, interface, major_version, timestamp)
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      interface_removed(target, realm, device_id, interface, major_version, timestamp) == :ok
    end)
  end

  def interface_removed(target, realm, device_id, interface, major_version, timestamp) do
    %InterfaceRemovedEvent{interface: interface, major_version: major_version}
    |> make_simple_event(
      :interface_removed_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target)
  end

  def path_created(targets, realm, device_id, interface, path, bson_value, timestamp)
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      path_created(target, realm, device_id, interface, path, bson_value, timestamp) == :ok
    end)
  end

  def path_created(target, realm, device_id, interface, path, bson_value, timestamp) do
    %PathCreatedEvent{interface: interface, path: path, bson_value: bson_value}
    |> make_simple_event(
      :path_created_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target)
  end

  def path_removed(targets, realm, device_id, interface, path, timestamp) when is_list(targets) do
    execute_all_ok(targets, fn target ->
      path_removed(target, realm, device_id, interface, path, timestamp) == :ok
    end)
  end

  def path_removed(target, realm, device_id, interface, path, timestamp) do
    %PathRemovedEvent{interface: interface, path: path}
    |> make_simple_event(
      :path_removed_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target)
  end

  def value_change(
        targets,
        realm,
        device_id,
        interface,
        path,
        old_bson_value,
        new_bson_value,
        timestamp
      )
      when is_list(targets) do
    execute_all_ok(targets, fn target ->
      value_change(
        target,
        realm,
        device_id,
        interface,
        path,
        old_bson_value,
        new_bson_value,
        timestamp
      ) ==
        :ok
    end)
  end

  def value_change(
        target,
        realm,
        device_id,
        interface,
        path,
        old_bson_value,
        new_bson_value,
        timestamp
      ) do
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
      device_id,
      timestamp
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
        new_bson_value,
        timestamp
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
        new_bson_value,
        timestamp
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
        new_bson_value,
        timestamp
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
      device_id,
      timestamp
    )
    |> dispatch_event(target)
  end

  defp make_simple_event(
         event,
         event_type,
         simple_trigger_id,
         parent_trigger_id,
         realm,
         device_id,
         timestamp
       ) do
    %SimpleEvent{
      simple_trigger_id: simple_trigger_id,
      parent_trigger_id: parent_trigger_id,
      realm: realm,
      device_id: device_id,
      timestamp: timestamp,
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

  defp wait_backoff_and_publish(:ok, _retry, _payload, _exchange, _routing_key, _headers) do
    :ok
  end

  defp wait_backoff_and_publish({:error, reason}, retry, payload, exchange, routing_key, headers) do
    Logger.warn(
      "Failed publish on events exchange with #{routing_key}. Reason: #{inspect(reason)}"
    )

    :rand.uniform(1 <<< (retry * 1000))
    |> :timer.sleep()

    next_retry =
      if retry <= @max_backoff_exponent do
        retry + 1
      else
        retry
      end

    AMQPEventsProducer.publish(payload, exchange, routing_key, headers)
    |> wait_backoff_and_publish(next_retry, payload, exchange, routing_key, headers)
  end

  defp wait_ok_publish(payload, exchange, routing_key, headers) do
    AMQPEventsProducer.publish(payload, exchange, routing_key, headers)
    |> wait_backoff_and_publish(1, payload, exchange, routing_key, headers)
  end

  defp dispatch_event(simple_event = %SimpleEvent{}, %AMQPTriggerTarget{
         exchange: target_exchange,
         routing_key: routing_key,
         static_headers: static_headers
       }) do
    {event_type, _event_struct} = simple_event.event

    exchange = target_exchange || Config.events_exchange_name!()

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

    result =
      SimpleEvent.encode(simple_event)
      |> wait_ok_publish(exchange, routing_key, headers)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :triggers_handler, :published_event],
      %{},
      %{
        realm: simple_event.realm,
        event_type: to_string(event_type)
      }
    )

    result
  end
end
