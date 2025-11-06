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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.DataHandler do
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.DataUpdaterPlant.DataUpdater.CachedPath
  alias Astarte.DataUpdaterPlant.DataUpdater.Cache
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataAccess.Data
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.TriggersHandler

  require Logger

  def handle_data(state, interface, path, payload, message_id, timestamp) do
    context = %{
      state: state,
      interface: interface,
      path: path,
      payload: payload,
      message_id: message_id,
      timestamp: timestamp
    }

    with :ok <- validate_interface(context),
         :ok <- validate_path(context),
         {:ok, interface_descriptor, context} <- maybe_handle_cache_miss(context),
         :ok <- can_write_on_interface?(context, interface_descriptor.ownership),
         {:ok, mapping} <- resolve_path(context, interface_descriptor),
         {value, value_timestamp, _metadata} <- decode_bson_payload(context),
         :ok <- validate_value_type(context, interface_descriptor, mapping, value),
         :ok <- can_set_to_value(context, interface_descriptor, mapping, value, value_timestamp) do
      execute_incoming_data_triggers(
        context,
        interface_descriptor,
        mapping,
        value,
        value_timestamp
      )

      maybe_explicit_value_timestamp =
        if mapping.explicit_timestamp,
          do: value_timestamp,
          else: div(timestamp, 10000)

      context = Map.put(context, :explicit_value_timestamp, maybe_explicit_value_timestamp)

      maybe_change_triggers =
        Core.Interface.get_value_change_triggers(
          context.state,
          interface_descriptor.interface_id,
          mapping.endpoint_id,
          path,
          value
        )

      previous_value =
        get_previous_value(context, interface_descriptor, mapping, maybe_change_triggers)

      context = Map.put(context, :previous_value, previous_value)

      :ok =
        maybe_execute_pre_change_triggers(
          context,
          interface_descriptor,
          value,
          maybe_change_triggers
        )

      realm_max_ttl = context.state.datastream_maximum_storage_retention

      db_max_ttl =
        max_ttl(mapping.database_retention_policy, realm_max_ttl, mapping.database_retention_ttl)

      context = Map.put(context, :db_max_ttl, db_max_ttl)

      # Here value cannot be nil, otherwise `can_set_to_value/5` would have not
      # been :ok
      if interface_descriptor.type == :datastream,
        do: maybe_insert_path(context, interface_descriptor, mapping)

      Queries.insert_value_into_db(
        context.state.realm,
        context.state.device_id,
        interface_descriptor,
        mapping,
        path,
        value,
        maybe_explicit_value_timestamp,
        timestamp,
        ttl: db_max_ttl
      )
      |> handle_result(context, maybe_change_triggers, interface_descriptor, mapping, value)
    end
  end

  defp maybe_execute_pre_change_triggers(
         context,
         interface_descriptor,
         value,
         {:ok, change_triggers}
       ) do
    %{
      state: state,
      path: path,
      previous_value: previous_value,
      explicit_value_timestamp: explicit_value_timestamp
    } = context

    Core.Trigger.execute_pre_change_triggers(
      change_triggers,
      state.realm,
      Device.encode_device_id(state.device_id),
      interface_descriptor.name,
      path,
      previous_value,
      value,
      explicit_value_timestamp,
      state.trigger_id_to_policy_name
    )
  end

  defp maybe_execute_pre_change_triggers(_, _, _, _), do: :ok

  defp maybe_execute_post_change_triggers(
         context,
         interface_descriptor,
         mapping,
         value,
         {:ok, change_triggers}
       ) do
    %{
      state: state,
      path: path,
      previous_value: previous_value,
      explicit_value_timestamp: explicit_value_timestamp
    } = context

    Core.Trigger.execute_post_change_triggers(
      state,
      change_triggers,
      interface_descriptor,
      mapping,
      path,
      previous_value,
      value,
      explicit_value_timestamp
    )
  end

  defp maybe_execute_post_change_triggers(_, _, _, _, _), do: :ok

  defp get_previous_value(context, interface_descriptor, mapping, {:ok, _change_triggers}) do
    %{state: state, path: path} = context

    case Data.fetch_property(state.realm, state.device_id, interface_descriptor, mapping, path) do
      {:ok, property_value} -> property_value
      _ -> nil
    end
  end

  defp get_previous_value(_, _, _, _), do: nil

  defp handle_result({:error, :unset_not_allowed}, context, _, _, _, _) do
    error = %{
      message: "Tried to unset a property with `allow_unset`=false.",
      logger_metadata: [tag: "unset_not_allowed"],
      error_name: "unset_not_allowed"
    }

    # with `unset_not_allowed` we do not want to update the stats
    Core.Error.handle_error(context, error, update_stats: false)
  end

  defp handle_result(:ok, context, maybe_change_triggers, interface_descriptor, mapping, value) do
    %{
      state: state,
      path: path,
      payload: payload,
      interface: interface,
      message_id: message_id,
      db_max_ttl: db_max_ttl
    } = context

    maybe_execute_post_change_triggers(
      context,
      interface_descriptor,
      mapping,
      value,
      maybe_change_triggers
    )

    paths_cache = Cache.put(state.paths_cache, {interface, path}, %CachedPath{}, db_max_ttl)
    state = %{state | paths_cache: paths_cache}

    MessageTracker.ack_delivery(state.message_tracker, message_id)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :processed_message],
      %{},
      %{
        realm: state.realm,
        interface_type: interface_descriptor.type
      }
    )

    update_stats(state, interface, interface_descriptor.major_version, path, payload)
  end

  defp maybe_insert_path(context, interface_descriptor, mapping) do
    %{
      state: state,
      interface: interface,
      path: path,
      timestamp: timestamp,
      explicit_value_timestamp: explicit_value_timestamp,
      db_max_ttl: db_max_ttl
    } = context

    cache_hit = Cache.has_key?(state.paths_cache, {interface, path})

    # Track path cache performance
    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_handler, :path_cache],
      %{},
      %{realm: state.realm, result: if(cache_hit, do: "hit", else: "miss")}
    )

    with false <- cache_hit,
         false <-
           Queries.fetch_path_expiry(
             state.realm,
             state.device_id,
             interface_descriptor,
             mapping,
             path
           )
           |> is_still_valid?(db_max_ttl) do
      Queries.insert_path_into_db(
        state.realm,
        state.device_id,
        interface_descriptor,
        mapping,
        path,
        explicit_value_timestamp,
        timestamp,
        ttl: path_ttl(db_max_ttl)
      )
    end
  end

  defp can_set_to_value(
         context,
         %InterfaceDescriptor{type: :datastream} = interface_descriptor,
         mapping,
         nil,
         value_timestamp
       ) do
    # We still want to execute incoming data triggers
    execute_incoming_data_triggers(context, interface_descriptor, mapping, nil, value_timestamp)

    error = %{
      message: "Tried to unset a datastream.",
      error_name: "unset_on_datastream",
      logger_metadata: [tag: "unset_on_datastream"]
    }

    Core.Error.handle_error(context, error, ask_clean_session: false, update_stats: false)
  end

  defp can_set_to_value(_context, _descriptor, _mapping, _value, _value_timestamp), do: :ok

  defp execute_incoming_data_triggers(
         context,
         interface_descriptor,
         mapping,
         value,
         value_timestamp
       ) do
    %{state: state, path: path, payload: payload} = context
    interface_id = interface_descriptor.interface_id

    maybe_explicit_value_timestamp =
      if mapping.explicit_timestamp,
        do: value_timestamp,
        else: div(context.timestamp, 10000)

    TriggersHandler.incoming_data(
      state.realm,
      state.device_id,
      state.groups,
      interface_descriptor.name,
      interface_id,
      mapping.endpoint_id,
      path,
      value,
      payload,
      maybe_explicit_value_timestamp,
      state
    )
  end

  defp maybe_handle_cache_miss(context) do
    %{interface: interface, state: state} = context

    cache_miss =
      state.interfaces
      |> Map.get(interface)
      |> Core.Interface.maybe_handle_cache_miss(interface, state)

    case cache_miss do
      {:error, :interface_loading_failed} ->
        # Track interface cache miss
        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_handler, :interface_cache_miss],
          %{},
          %{realm: state.realm, interface: interface, result: "failed"}
        )

        error = %{
          message: "Cannot load interface: #{interface}.",
          logger_metadata: [tag: "interface_loading_failed"],
          error_name: "interface_loading_failed"
        }

        Core.Error.handle_error(context, error)

      {:ok, descriptor, state} ->
        # Track successful interface cache hit or successful load
        cache_result =
          if Map.has_key?(state.interfaces, interface), do: "hit", else: "miss_resolved"

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_handler, :interface_cache],
          %{},
          %{realm: state.realm, interface: interface, result: cache_result}
        )

        new_context = Map.put(context, :state, state)
        {:ok, descriptor, new_context}
    end
  end

  defp resolve_path(context, interface_descriptor) do
    %{interface: interface, path: path, state: state} = context
    mappings = Core.Interface.resolve_path(path, interface_descriptor, state.mappings)

    case mappings do
      {:error, :mapping_not_found} ->
        error = %{
          message: "Mapping not found for #{interface}#{path}. Maybe outdated introspection?",
          logger_metadata: [tag: "mapping_not_found"],
          error_name: "mapping_not_found"
        }

        Core.Error.handle_error(context, error)

      {:guessed, _guessed_endpoints} ->
        error = %{
          message: "Mapping guessed for #{interface}#{path}. Maybe outdated introspection?",
          logger_metadata: [tag: "ambiguous_path"],
          error_name: "ambiguous_path"
        }

        Core.Error.handle_error(context, error)

      ok ->
        ok
    end
  end

  defp decode_bson_payload(context) do
    %{payload: payload, timestamp: timestamp, interface: interface, path: path} = context
    decoding = PayloadsDecoder.decode_bson_payload(payload, timestamp)

    with {:error, :undecodable_bson_payload} <- decoding do
      error = %{
        message:
          "Invalid BSON base64-encoded payload: #{inspect(Base.encode64(payload))} sent to #{interface}#{path}.",
        logger_metadata: [tag: "undecodable_bson_payload"],
        error_name: "undecodable_bson_payload"
      }

      Core.Error.handle_error(context, error)
    end
  end

  defp path_ttl(nil), do: nil
  defp path_ttl(retention_secs), do: retention_secs * 2 + div(retention_secs, 2)

  defp is_still_valid?({:error, :property_not_set}, _ttl), do: false
  defp is_still_valid?({:ok, :no_expiry}, _ttl), do: true
  defp is_still_valid?({:ok, _expiry_date}, nil), do: false

  defp is_still_valid?({:ok, expiry_date}, ttl) do
    expiry_secs = DateTime.to_unix(expiry_date)

    now_secs =
      DateTime.utc_now()
      |> DateTime.to_unix()

    # 3600 seconds is one hour
    # this adds 1 hour of tolerance to clock synchronization issues
    now_secs + ttl + 3600 < expiry_secs
  end

  defp validate_interface(%{interface: interface} = context) do
    case String.valid?(interface) do
      true -> :ok
      false -> invalid_interface_error(context)
    end
  end

  defp invalid_interface_error(%{interface: interface} = context) do
    error =
      %{
        message: "Received invalid interface: #{inspect(interface)}.",
        logger_metadata: [tag: "invalid_interface"],
        error_name: "invalid_interface"
      }

    Core.Error.handle_error(context, error, update_stats: false)
  end

  defp validate_path(%{path: path} = context),
    do: valid_path_or_error(context, String.valid?(path), String.contains?(path, "//"))

  defp valid_path_or_error(_context, true, false), do: :ok

  defp valid_path_or_error(%{path: path} = context, _, _) do
    error = %{
      message: "Received invalid path: #{inspect(path)}.",
      logger_metadata: [tag: "invalid_path"],
      error_name: "invalid_path"
    }

    Core.Error.handle_error(context, error)
  end

  defp can_write_on_interface?(_context, :device), do: :ok

  defp can_write_on_interface?(context, :server) do
    %{interface: interface, path: path, payload: payload, timestamp: timestamp} = context

    message =
      "Tried to write on server owned interface: #{interface} on " <>
        "path: #{path}, base64-encoded payload: #{inspect(Base.encode64(payload))}, timestamp: #{inspect(timestamp)}."

    tag = "write_on_server_owned_interface"

    error_name = "write_on_server_owned_interface"

    error = %{
      message: message,
      logger_metadata: [tag: tag],
      error_name: error_name
    }

    Core.Error.handle_error(context, error)
  end

  defp validate_value_type(context, interface_descriptor, mapping, value) do
    %{interface: interface, path: path, payload: payload, state: state} = context

    expected_types =
      Core.Interface.extract_expected_types(
        path,
        interface_descriptor,
        mapping,
        state.mappings
      )

    validation = validate_value_type(expected_types, value)

    case validation do
      {:error, :unexpected_value_type} ->
        error = %{
          message:
            "Received invalid value: #{inspect(Base.encode64(payload))} sent to #{interface}#{path}.",
          logger_metadata: [tag: "unexpected_value_type"],
          error_name: "unexpected_value_type"
        }

        Core.Error.handle_error(context, error)

      {:error, :unexpected_object_key} ->
        error = %{
          message:
            "Received object with unexpected key, object base64 is: #{inspect(Base.encode64(payload))} sent to #{interface}#{path}.",
          logger_metadata: [tag: "unexpected_value_type"],
          error_name: "unexpected_value_type"
        }

        Core.Error.handle_error(context, error)

      {:error, :value_size_exceeded} ->
        error = %{
          message:
            "Received huge base64-encoded payload: #{inspect(Base.encode64(payload))} sent to #{interface}#{path}.",
          logger_metadata: [tag: "value_size_exceeded"],
          error_name: "value_size_exceeded"
        }

        Core.Error.handle_error(context, error)

      :ok ->
        :ok
    end
  end

  # TODO: We need tests for this function
  def validate_value_type(expected_type, %DateTime{} = value) do
    ValueType.validate_value(expected_type, value)
  end

  # From Cyanide 2.0, binaries are decoded as %Cyanide.Binary{}
  def validate_value_type(expected_type, %Cyanide.Binary{} = value) do
    %Cyanide.Binary{subtype: _subtype, data: bin} = value
    validate_value_type(expected_type, bin)
  end

  # Explicitly match on all other structs to avoid pattern matching them as maps below
  def validate_value_type(_expected_type, %_{} = _unsupported_struct) do
    {:error, :unexpected_value_type}
  end

  def validate_value_type(%{} = expected_types, %{} = object) do
    Enum.reduce_while(object, :ok, fn {key, value}, _acc ->
      with {:ok, expected_type} <- Map.fetch(expected_types, key),
           :ok <- ValueType.validate_value(expected_type, value) do
        {:cont, :ok}
      else
        {:error, reason} ->
          {:halt, {:error, reason}}

        :error ->
          Logger.warning("Unexpected key #{inspect(key)} in object #{inspect(object)}.",
            tag: "unexpected_object_key"
          )

          {:halt, {:error, :unexpected_object_key}}
      end
    end)
  end

  # TODO: we should test for this kind of unexpected messages
  # We expected an individual value, but we received an aggregated
  def validate_value_type(_expected_types, %{} = _object) do
    {:error, :unexpected_value_type}
  end

  # TODO: we should test for this kind of unexpected messages
  # We expected an aggregated, but we received an individual
  def validate_value_type(%{} = _expected_types, _object) do
    {:error, :unexpected_value_type}
  end

  def validate_value_type(expected_type, value) do
    if value != nil do
      ValueType.validate_value(expected_type, value)
    else
      :ok
    end
  end

  def update_stats(state, interface, major, path, payload) do
    exchanged_bytes = byte_size(payload) + byte_size(interface) + byte_size(path)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :exchanged_bytes],
      %{bytes: exchanged_bytes},
      %{realm: state.realm}
    )

    %{
      state
      | total_received_msgs: state.total_received_msgs + 1,
        total_received_bytes: state.total_received_bytes + exchanged_bytes
    }
    |> update_interface_stats(interface, major, path, payload)
  end

  defp update_interface_stats(state, interface, major, _path, _payload)
       when interface == "" or major == nil do
    # Skip when we can't identify a specific major or interface is empty (e.g. control messages)
    # TODO: restructure code to access major version even in the else branch of handle_data
    state
  end

  defp update_interface_stats(state, interface, major, path, payload) do
    %State{
      initial_interface_exchanged_bytes: initial_interface_exchanged_bytes,
      initial_interface_exchanged_msgs: initial_interface_exchanged_msgs,
      interface_exchanged_bytes: interface_exchanged_bytes,
      interface_exchanged_msgs: interface_exchanged_msgs
    } = state

    bytes = byte_size(payload) + byte_size(interface) + byte_size(path)

    # If present, get exchanged bytes from live count, otherwise fallback to initial
    # count and in case nothing is there too, fallback to 0
    exchanged_bytes =
      Map.get_lazy(interface_exchanged_bytes, {interface, major}, fn ->
        Map.get(initial_interface_exchanged_bytes, {interface, major}, 0)
      end)

    # As above but with msgs
    exchanged_msgs =
      Map.get_lazy(interface_exchanged_msgs, {interface, major}, fn ->
        Map.get(initial_interface_exchanged_msgs, {interface, major}, 0)
      end)

    updated_interface_exchanged_bytes =
      Map.put(interface_exchanged_bytes, {interface, major}, exchanged_bytes + bytes)

    updated_interface_exchanged_msgs =
      Map.put(interface_exchanged_msgs, {interface, major}, exchanged_msgs + 1)

    %{
      state
      | interface_exchanged_bytes: updated_interface_exchanged_bytes,
        interface_exchanged_msgs: updated_interface_exchanged_msgs
    }
  end

  defp max_ttl(:use_ttl, realm_max_ttl, db_ttl) when is_integer(realm_max_ttl),
    do: min(db_ttl, realm_max_ttl)

  defp max_ttl(:use_ttl, _, db_ttl), do: db_ttl

  defp max_ttl(_db_retention_policy, realm_max_ttl, _db_ttl) when is_integer(realm_max_ttl),
    do: realm_max_ttl

  defp max_ttl(_, _, _), do: nil
end
