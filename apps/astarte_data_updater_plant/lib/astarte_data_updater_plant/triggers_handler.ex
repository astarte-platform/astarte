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
  # https://hexdocs.pm/elixir/1.13.4/Bitwise.html
  import Bitwise
  require Logger
  alias Astarte.DataUpdaterPlant.Config

  @moduledoc """
  This module handles the triggers by generating the events requested
  by the Trigger targets
  """

  @max_backoff_exponent 8
  @max_rand trunc(:math.pow(2, 32) - 1)

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
    SimpleEvent,
    ValueChangeAppliedEvent,
    ValueChangeEvent
  }

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.DataUpdaterPlant.AMQPEventsProducer

  def register_target(%AMQPTriggerTarget{exchange: nil} = _target) do
    # Default exchange, no need to declare it
    :ok
  end

  def register_target(%AMQPTriggerTarget{exchange: exchange} = _target) do
    AMQPEventsProducer.declare_exchange(exchange)
  end

  def device_connected(targets, realm, device_id, ip_address, timestamp) when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      device_connected(target, realm, device_id, ip_address, timestamp, policy) == :ok
    end)
  end

  def device_connected(target, realm, device_id, ip_address, timestamp, policy) do
    %DeviceConnectedEvent{device_ip_address: ip_address}
    |> make_simple_event(
      :device_connected_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target, policy)
  end

  def device_disconnected(targets, realm, device_id, timestamp) when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      device_disconnected(target, realm, device_id, timestamp, policy) == :ok
    end)
  end

  def device_disconnected(target, realm, device_id, timestamp, policy) do
    %DeviceDisconnectedEvent{}
    |> make_simple_event(
      :device_disconnected_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target, policy)
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
    |> make_simple_event(
      :device_error_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target, policy)
  end

  def incoming_data(targets, realm, device_id, interface, path, bson_value, timestamp)
      when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      incoming_data(target, realm, device_id, interface, path, bson_value, timestamp, policy) ==
        :ok
    end)
  end

  def incoming_data(
        target,
        realm,
        device_id,
        interface,
        path,
        bson_value,
        timestamp,
        policy
      ) do
    %IncomingDataEvent{interface: interface, path: path, bson_value: bson_value}
    |> make_simple_event(
      :incoming_data_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target, policy)
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
    |> make_simple_event(
      :incoming_introspection_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target, policy)
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
    |> make_simple_event(
      :interface_added_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target, policy)
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
    |> make_simple_event(
      :interface_minor_updated_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target, policy)
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
    |> make_simple_event(
      :interface_removed_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target, policy)
  end

  def path_created(targets, realm, device_id, interface, path, bson_value, timestamp)
      when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      path_created(target, realm, device_id, interface, path, bson_value, timestamp, policy) ==
        :ok
    end)
  end

  def path_created(
        target,
        realm,
        device_id,
        interface,
        path,
        bson_value,
        timestamp,
        policy
      ) do
    %PathCreatedEvent{interface: interface, path: path, bson_value: bson_value}
    |> make_simple_event(
      :path_created_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target, policy)
  end

  def path_removed(targets, realm, device_id, interface, path, timestamp) when is_list(targets) do
    execute_all_ok(targets, fn {target, policy} ->
      path_removed(target, realm, device_id, interface, path, timestamp, policy) == :ok
    end)
  end

  def path_removed(target, realm, device_id, interface, path, timestamp, policy) do
    %PathRemovedEvent{interface: interface, path: path}
    |> make_simple_event(
      :path_removed_event,
      target.simple_trigger_id,
      target.parent_trigger_id,
      realm,
      device_id,
      timestamp
    )
    |> dispatch_event(target, policy)
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
    execute_all_ok(targets, fn {target, policy} ->
      value_change(
        target,
        realm,
        device_id,
        interface,
        path,
        old_bson_value,
        new_bson_value,
        timestamp,
        policy
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
        timestamp,
        policy
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
    |> dispatch_event(target, policy)
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
    execute_all_ok(targets, fn {target, policy} ->
      value_change_applied(
        target,
        realm,
        device_id,
        interface,
        path,
        old_bson_value,
        new_bson_value,
        timestamp,
        policy
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
        timestamp,
        policy
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
    |> dispatch_event(target, policy)
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

  defp wait_backoff_and_publish(:ok, _retry, _exchange, _routing_key, _payload, _opts) do
    :ok
  end

  defp wait_backoff_and_publish({:error, reason}, retry, exchange, routing_key, payload, opts) do
    Logger.warning(
      "Failed publish on events exchange with #{routing_key}. Reason: #{inspect(reason)}"
    )

    retry
    |> compute_backoff_time()
    |> :timer.sleep()

    next_retry =
      if retry <= @max_backoff_exponent do
        retry + 1
      else
        retry
      end

    AMQPEventsProducer.publish(exchange, routing_key, payload, opts)
    |> wait_backoff_and_publish(next_retry, exchange, routing_key, payload, opts)
  end

  defp wait_ok_publish(exchange, routing_key, payload, opts) do
    AMQPEventsProducer.publish(exchange, routing_key, payload, opts)
    |> wait_backoff_and_publish(1, exchange, routing_key, payload, opts)
  end

  defp dispatch_event(
         simple_event = %SimpleEvent{},
         %AMQPTriggerTarget{
           exchange: target_exchange,
           routing_key: routing_key,
           static_headers: static_headers,
           message_expiration_ms: message_expiration_ms,
           message_priority: message_priority,
           message_persistent: message_persistent
         },
         policy_name
       ) do
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

    {routing_key, headers} =
      update_if_has_policy(
        routing_key,
        headers,
        simple_event.realm,
        policy_name
      )

    opts_with_nil = [
      expiration: message_expiration_ms && to_string(message_expiration_ms),
      priority: message_priority,
      persistent: message_persistent,
      message_id:
        generate_message_id(simple_event.realm, simple_event.device_id, simple_event.timestamp)
    ]

    opts = Enum.filter(opts_with_nil, fn {_k, v} -> v != nil end)

    payload = SimpleEvent.encode(simple_event)

    result = wait_ok_publish(exchange, routing_key, payload, [{:headers, headers} | opts])

    Logger.debug("headers: #{inspect(headers)}, routing key: #{inspect(routing_key)}")

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

  defp compute_backoff_time(current_attempt) do
    minimum_duration = (1 <<< current_attempt) * 1000
    minimum_duration + round(minimum_duration * 0.25 * :rand.uniform())
  end

  defp generate_message_id(realm, device_id, timestamp) do
    realm_trunc = String.slice(realm, 0..63)
    device_id_trunc = String.slice(device_id, 0..15)
    timestamp_hex_str = Integer.to_string(timestamp, 16)
    rnd = Enum.random(0..@max_rand) |> Integer.to_string(16)

    "#{realm_trunc}-#{device_id_trunc}-#{timestamp_hex_str}-#{rnd}"
  end

  defp update_if_has_policy(
         "trigger_engine",
         headers,
         realm,
         policy_name
       ) do
    policy_name = policy_name || "@default"

    headers = [
      {"x_astarte_trigger_policy", policy_name}
      | headers
    ]

    routing_key = generate_routing_key(realm, policy_name)

    {routing_key, headers}
  end

  defp update_if_has_policy(
         routing_key,
         headers,
         _realm,
         _policy_name
       ) do
    {routing_key, headers}
  end

  defp generate_routing_key(realm, policy) do
    "#{realm}_#{policy}"
  end
end
