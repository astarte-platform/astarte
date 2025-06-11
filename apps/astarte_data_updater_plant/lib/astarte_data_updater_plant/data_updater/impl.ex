#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Impl do
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.Core.CQLUtils
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger, as: ProtobufDataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils, as: SimpleTriggersProtobufUtils
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataUpdaterPlant.DataUpdater.Cache
  alias Astarte.DataUpdaterPlant.DataUpdater.EventTypeUtils
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.DataUpdaterPlant.TimeBasedActions
  require Logger

  def init_state(realm, device_id, message_tracker) do
    MessageTracker.register_data_updater(message_tracker)
    Process.monitor(message_tracker)

    new_state = %State{
      realm: realm,
      device_id: device_id,
      message_tracker: message_tracker,
      connected: true,
      groups: [],
      interfaces: %{},
      interface_ids_to_name: %{},
      interfaces_by_expiry: [],
      mappings: %{},
      paths_cache: Cache.new(Config.paths_cache_size!()),
      device_triggers: %{},
      data_triggers: %{},
      volatile_triggers: [],
      interface_exchanged_bytes: %{},
      interface_exchanged_msgs: %{},
      last_seen_message: 0,
      last_device_triggers_refresh: 0,
      last_groups_refresh: 0,
      trigger_id_to_policy_name: %{},
      discard_messages: false,
      last_deletion_in_progress_refresh: 0,
      last_datastream_maximum_retention_refresh: 0
    }

    encoded_device_id = Device.encode_device_id(device_id)
    Logger.metadata(realm: realm, device_id: encoded_device_id)
    Logger.info("Created device process.", tag: "device_process_created")

    stats_and_introspection =
      Queries.retrieve_device_stats_and_introspection!(new_state.realm, device_id)

    # TODO this could be a bang!
    {:ok, ttl} = Queries.get_datastream_maximum_storage_retention(new_state.realm)

    Map.merge(new_state, stats_and_introspection)
    |> Map.put(:datastream_maximum_storage_retention, ttl)
  end

  def handle_deactivation(_state) do
    Logger.info("Deactivated device process.", tag: "device_process_deactivated")

    :ok
  end

  def handle_connection(%State{discard_messages: true} = state, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_connection(state, ip_address_string, message_id, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    timestamp_ms = div(timestamp, 10_000)

    ip_address_result =
      ip_address_string
      |> to_charlist()
      |> :inet.parse_address()

    ip_address =
      case ip_address_result do
        {:ok, ip_address} ->
          ip_address

        _ ->
          Logger.warning("Received invalid IP address #{ip_address_string}.")
          {0, 0, 0, 0}
      end

    Queries.set_device_connected!(
      new_state.realm,
      new_state.device_id,
      DateTime.from_unix!(timestamp_ms, :millisecond),
      ip_address
    )

    trigger_target_with_policy_list =
      Map.get(new_state.device_triggers, :on_device_connection, [])
      |> Enum.map(fn target ->
        {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
      end)

    device_id_string = Device.encode_device_id(new_state.device_id)

    TriggersHandler.device_connected(
      trigger_target_with_policy_list,
      new_state.realm,
      device_id_string,
      ip_address_string,
      timestamp_ms
    )

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)
    Logger.info("Device connected.", ip_address: ip_address_string, tag: "device_connected")

    :telemetry.execute([:astarte, :data_updater_plant, :data_updater, :device_connection], %{}, %{
      realm: new_state.realm
    })

    %{new_state | connected: true, last_seen_message: timestamp}
  end

  def handle_internal(state, path, payload, message_id, timestamp) do
    Core.InternalHandler.handle_internal(state, path, payload, message_id, timestamp)
  end

  def start_device_deletion(state, timestamp) do
    # Device deletion is among time-based actions
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    {:ok, new_state}
  end

  def handle_disconnection(state, message_id, timestamp) do
    new_state =
      state
      |> TimeBasedActions.execute_time_based_actions(timestamp)
      |> Core.Device.set_device_disconnected(timestamp)

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)
    Logger.info("Device disconnected.", tag: "device_disconnected")

    %{new_state | last_seen_message: timestamp}
  end

  def handle_data(%State{discard_messages: true} = state, _, _, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_data(state, interface, path, payload, message_id, timestamp) do
    TimeBasedActions.execute_time_based_actions(state, timestamp)
    |> Core.DataHandler.handle_data(interface, path, payload, message_id, timestamp)
  end

  def handle_introspection(%State{discard_messages: true} = state, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_introspection(state, payload, message_id, timestamp) do
    with {:ok, new_introspection_list} <- PayloadsDecoder.parse_introspection(payload) do
      Core.Device.process_introspection(
        state,
        new_introspection_list,
        payload,
        message_id,
        timestamp
      )
    else
      {:error, :invalid_introspection} ->
        Logger.warning("Discarding invalid introspection: #{inspect(Base.encode64(payload))}.",
          tag: "invalid_introspection"
        )

        {:ok, new_state} = Core.Device.ask_clean_session(state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_introspection],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "base64_payload" => base64_payload
        }

        Core.Trigger.execute_device_error_triggers(
          new_state,
          "invalid_introspection",
          error_metadata,
          timestamp
        )

        Core.DataHandler.update_stats(new_state, "", nil, "", payload)
    end
  end

  defdelegate handle_control(state, path, payload, message_id, timestamp), to: Core.ControlHandler

  def handle_install_volatile_trigger(
        %State{discard_messages: true} = state,
        _,
        message_id,
        _
      ) do
    MessageTracker.ack_delivery(state.message_tracker, message_id)
    state
  end

  def handle_install_volatile_trigger(
        state,
        object_id,
        object_type,
        parent_id,
        trigger_id,
        simple_trigger,
        trigger_target
      ) do
    trigger = SimpleTriggersProtobufUtils.deserialize_simple_trigger(simple_trigger)

    target =
      SimpleTriggersProtobufUtils.deserialize_trigger_target(trigger_target)
      |> Map.put(:simple_trigger_id, trigger_id)
      |> Map.put(:parent_trigger_id, parent_id)

    volatile_triggers_list = [
      {{object_id, object_type}, {trigger, target}} | state.volatile_triggers
    ]

    new_state = Map.put(state, :volatile_triggers, volatile_triggers_list)

    if Map.has_key?(new_state.interface_ids_to_name, object_id) do
      interface_name = Map.get(new_state.interface_ids_to_name, object_id)
      %InterfaceDescriptor{automaton: automaton} = new_state.interfaces[interface_name]

      case trigger do
        {:data_trigger, %ProtobufDataTrigger{match_path: "/*"}} ->
          {:ok, Core.Trigger.load_trigger(new_state, trigger, target)}

        {:data_trigger, %ProtobufDataTrigger{match_path: match_path}} ->
          with {:ok, _endpoint_id} <- EndpointsAutomaton.resolve_path(match_path, automaton) do
            {:ok, Core.Trigger.load_trigger(new_state, trigger, target)}
          else
            {:guessed, _} ->
              # State rollback here
              {{:error, :invalid_match_path}, state}

            {:error, :not_found} ->
              # State rollback here
              {{:error, :invalid_match_path}, state}
          end
      end
    else
      case trigger do
        {:data_trigger, %ProtobufDataTrigger{interface_name: "*"}} ->
          {:ok, Core.Trigger.load_trigger(new_state, trigger, target)}

        {:data_trigger,
         %ProtobufDataTrigger{
           interface_name: interface_name,
           interface_major: major,
           match_path: "/*"
         }} ->
          with :ok <-
                 InterfaceQueries.check_if_interface_exists(state.realm, interface_name, major) do
            {:ok, new_state}
          else
            {:error, reason} ->
              # State rollback here
              {{:error, reason}, state}
          end

        {:data_trigger,
         %ProtobufDataTrigger{
           interface_name: interface_name,
           interface_major: major,
           match_path: match_path
         }} ->
          with {:ok, %InterfaceDescriptor{automaton: automaton}} <-
                 InterfaceQueries.fetch_interface_descriptor(state.realm, interface_name, major),
               {:ok, _endpoint_id} <- EndpointsAutomaton.resolve_path(match_path, automaton) do
            {:ok, new_state}
          else
            {:error, :not_found} ->
              {{:error, :invalid_match_path}, state}

            {:guessed, _} ->
              {{:error, :invalid_match_path}, state}

            {:error, reason} ->
              # State rollback here
              {{:error, reason}, state}
          end

        {:device_trigger, _} ->
          {:ok, Core.Trigger.load_trigger(new_state, trigger, target)}
      end
    end
  end

  def handle_delete_volatile_trigger(%State{discard_messages: true} = state, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_delete_volatile_trigger(state, trigger_id) do
    {new_volatile, maybe_trigger} =
      Enum.reduce(state.volatile_triggers, {[], nil}, fn item, {acc, found} ->
        {_, {_simple_trigger, trigger_target}} = item

        if trigger_target.simple_trigger_id == trigger_id do
          {acc, item}
        else
          {[item | acc], found}
        end
      end)

    case maybe_trigger do
      {{obj_id, obj_type}, {simple_trigger, trigger_target}} ->
        %{state | volatile_triggers: new_volatile}
        |> delete_volatile_trigger({obj_id, obj_type}, {simple_trigger, trigger_target})

      nil ->
        {:ok, state}
    end
  end

  defp delete_volatile_trigger(
         state,
         {obj_id, _obj_type},
         {{:data_trigger, proto_buf_data_trigger}, trigger_target_to_be_deleted}
       ) do
    if Map.get(state.interface_ids_to_name, obj_id) do
      data_trigger_to_be_deleted =
        SimpleTriggersProtobufUtils.simple_trigger_to_data_trigger(proto_buf_data_trigger)

      data_triggers = state.data_triggers

      event_type =
        EventTypeUtils.pretty_data_trigger_type(proto_buf_data_trigger.data_trigger_type)

      data_trigger_key =
        Core.DataTrigger.data_trigger_to_key(state, data_trigger_to_be_deleted, event_type)

      existing_triggers_for_key = Map.get(data_triggers, data_trigger_key, [])

      # Separate triggers for key between the trigger congruent with the one being deleted
      # and all the other triggers
      {congruent_data_trigger_for_key, other_data_triggers_for_key} =
        Enum.reduce(existing_triggers_for_key, {nil, []}, fn
          trigger, {congruent_data_trigger_for_key, other_data_triggers_for_key} ->
            if DataTrigger.are_congruent?(trigger, data_trigger_to_be_deleted) do
              {trigger, other_data_triggers_for_key}
            else
              {congruent_data_trigger_for_key, [trigger | other_data_triggers_for_key]}
            end
        end)

      next_data_triggers_for_key =
        case congruent_data_trigger_for_key do
          nil ->
            # Trying to delete an unexisting volatile trigger, just return old data triggers
            existing_triggers_for_key

          %DataTrigger{trigger_targets: [^trigger_target_to_be_deleted]} ->
            # The target of the deleted trigger was the only target, just remove it
            other_data_triggers_for_key

          %DataTrigger{trigger_targets: targets} ->
            # The trigger has other targets, drop the one that is being deleted and update
            new_trigger_targets = Enum.reject(targets, &(&1 == trigger_target_to_be_deleted))

            new_congruent_data_trigger_for_key = %{
              congruent_data_trigger_for_key
              | trigger_targets: new_trigger_targets
            }

            [new_congruent_data_trigger_for_key | other_data_triggers_for_key]
        end

      next_data_triggers =
        if is_list(next_data_triggers_for_key) and length(next_data_triggers_for_key) > 0 do
          Map.put(data_triggers, data_trigger_key, next_data_triggers_for_key)
        else
          Map.delete(data_triggers, data_trigger_key)
        end

      {:ok, %{state | data_triggers: next_data_triggers}}
    else
      {:ok, state}
    end
  end

  defp delete_volatile_trigger(
         state,
         {_obj_id, _obj_type},
         {{:device_trigger, proto_buf_device_trigger}, trigger_target}
       ) do
    event_type =
      EventTypeUtils.pretty_device_event_type(proto_buf_device_trigger.device_event_type)

    device_triggers = state.device_triggers

    updated_targets_list =
      Map.get(device_triggers, event_type, [])
      |> Enum.reject(fn target ->
        target == trigger_target
      end)

    updated_device_triggers = Map.put(device_triggers, event_type, updated_targets_list)

    {:ok, %{state | device_triggers: updated_device_triggers}}
  end

  def resend_all_properties(state) do
    Logger.debug("Device introspection: #{inspect(state.introspection)}")

    Enum.reduce_while(state.introspection, {:ok, state}, fn {interface, _}, {:ok, state_acc} ->
      maybe_descriptor = Map.get(state_acc.interfaces, interface)

      with {:ok, interface_descriptor, new_state} <-
             Core.Interface.maybe_handle_cache_miss(maybe_descriptor, interface, state_acc),
           :ok <- resend_all_interface_properties(new_state, interface_descriptor) do
        {:cont, {:ok, new_state}}
      else
        {:error, :interface_loading_failed} ->
          Logger.warning("Failed #{interface} interface loading.")
          {:halt, {:error, :sending_properties_to_interface_failed}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp resend_all_interface_properties(
         %State{realm: realm, device_id: device_id, mappings: mappings} = _state,
         %InterfaceDescriptor{type: :properties, ownership: :server} = interface_descriptor
       ) do
    encoded_device_id = Device.encode_device_id(device_id)

    Core.Interface.each_interface_mapping(mappings, interface_descriptor, fn mapping ->
      %Mapping{value_type: value_type} = mapping

      column_name =
        CQLUtils.type_to_db_column_name(value_type) |> String.to_existing_atom()

      Queries.retrieve_property_values(realm, device_id, interface_descriptor, mapping)
      |> Enum.reduce_while(:ok, fn %{:path => path, ^column_name => value}, _acc ->
        case send_value(realm, encoded_device_id, interface_descriptor.name, path, value) do
          {:ok, _bytes} ->
            # TODO: use the returned bytes count in stats
            {:cont, :ok}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
    end)
  end

  defp resend_all_interface_properties(_state, %InterfaceDescriptor{} = _descriptor) do
    :ok
  end

  defp send_value(realm, device_id_string, interface_name, path, value) do
    topic = "#{realm}/#{device_id_string}/#{interface_name}#{path}"
    encapsulated_value = %{v: value}

    bson_value = Cyanide.encode!(encapsulated_value)

    Logger.debug("Going to publish #{inspect(encapsulated_value)} on #{topic}.")

    case VMQPlugin.publish(topic, bson_value, 2) do
      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote == 1 ->
        {:ok, byte_size(topic) + byte_size(bson_value)}

      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote > 1 ->
        # This should not happen so we print a warning, but we consider it a succesful publish
        Logger.warning(
          "Multiple match while publishing #{inspect(encapsulated_value)} on #{topic}.",
          tag: "publish_multiple_matches"
        )

        {:ok, byte_size(topic) + byte_size(bson_value)}

      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote == 0 ->
        {:error, :session_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
