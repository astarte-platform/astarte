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
         :ok <- validate_value_type(context, interface_descriptor, mapping, value) do
      interface_id = interface_descriptor.interface_id

      endpoint_id = mapping.endpoint_id
      db_retention_policy = mapping.database_retention_policy
      db_ttl = mapping.database_retention_ttl
      device_id_string = Device.encode_device_id(state.device_id)
      state = context.state

      maybe_explicit_value_timestamp =
        if mapping.explicit_timestamp,
          do: value_timestamp,
          else: div(timestamp, 10000)

      Core.DataTrigger.execute_incoming_data_triggers(
        state,
        device_id_string,
        interface_descriptor.name,
        interface_id,
        path,
        endpoint_id,
        payload,
        value,
        maybe_explicit_value_timestamp
      )

      {has_change_triggers, change_triggers} =
        Core.Interface.get_value_change_triggers(state, interface_id, endpoint_id, path, value)

      previous_value =
        with {:has_change_triggers, :ok} <- {:has_change_triggers, has_change_triggers},
             {:ok, property_value} <-
               Data.fetch_property(
                 state.realm,
                 state.device_id,
                 interface_descriptor,
                 mapping,
                 path
               ) do
          property_value
        else
          {:has_change_triggers, _not_ok} ->
            nil

          {:error, :property_not_set} ->
            nil
        end

      if has_change_triggers == :ok do
        :ok =
          Core.Trigger.execute_pre_change_triggers(
            change_triggers,
            state.realm,
            device_id_string,
            interface_descriptor.name,
            path,
            previous_value,
            value,
            maybe_explicit_value_timestamp,
            state.trigger_id_to_policy_name
          )
      end

      realm_max_ttl = state.datastream_maximum_storage_retention

      db_max_ttl =
        cond do
          db_retention_policy == :use_ttl and is_integer(realm_max_ttl) ->
            min(db_ttl, realm_max_ttl)

          db_retention_policy == :use_ttl ->
            db_ttl

          is_integer(realm_max_ttl) ->
            realm_max_ttl

          true ->
            nil
        end

      cond do
        interface_descriptor.type == :datastream and value != nil ->
          :ok =
            cond do
              Cache.has_key?(state.paths_cache, {interface, path}) ->
                :ok

              is_still_valid?(
                # TODO this is now a bang!
                Queries.fetch_path_expiry(
                  state.realm,
                  state.device_id,
                  interface_descriptor,
                  mapping,
                  path
                ),
                db_max_ttl
              ) ->
                :ok

              true ->
                Queries.insert_path_into_db(
                  state.realm,
                  state.device_id,
                  interface_descriptor,
                  mapping,
                  path,
                  maybe_explicit_value_timestamp,
                  timestamp,
                  ttl: path_ttl(db_max_ttl)
                )
            end

        interface_descriptor.type == :datastream ->
          Logger.warning("Tried to unset a datastream.", tag: "unset_on_datastream")
          MessageTracker.discard(state.message_tracker, message_id)

          :telemetry.execute(
            [:astarte, :data_updater_plant, :data_updater, :discarded_message],
            %{},
            %{realm: state.realm}
          )

          base64_payload = Base.encode64(payload)

          error_metadata = %{
            "interface" => inspect(interface),
            "path" => inspect(path),
            "base64_payload" => base64_payload
          }

          Core.Trigger.execute_device_error_triggers(
            state,
            "unset_on_datastream",
            error_metadata,
            timestamp
          )

          raise "Unsupported"

        true ->
          :ok
      end

      # TODO: handle insert failures here
      insert_result =
        Queries.insert_value_into_db(
          state.realm,
          state.device_id,
          interface_descriptor,
          mapping,
          path,
          value,
          maybe_explicit_value_timestamp,
          timestamp,
          ttl: db_max_ttl
        )

      case insert_result do
        {:error, :unset_not_allowed} ->
          Logger.warning("Tried to unset a property with `allow_unset`=false.",
            tag: "unset_not_allowed"
          )

          MessageTracker.discard(state.message_tracker, message_id)

          :telemetry.execute(
            [:astarte, :data_updater_plant, :data_updater, :discarded_message],
            %{},
            %{realm: state.realm}
          )

          base64_payload = Base.encode64(payload)

          error_metadata = %{
            "interface" => inspect(interface),
            "path" => inspect(path),
            "base64_payload" => base64_payload
          }

          Core.Trigger.execute_device_error_triggers(
            state,
            "unset_not_allowed",
            error_metadata,
            timestamp
          )

        :ok ->
          if has_change_triggers == :ok do
            :ok =
              Core.Trigger.execute_post_change_triggers(
                change_triggers,
                state.realm,
                device_id_string,
                interface_descriptor.name,
                path,
                previous_value,
                value,
                maybe_explicit_value_timestamp,
                state.trigger_id_to_policy_name
              )
          end

          ttl = db_max_ttl
          paths_cache = Cache.put(state.paths_cache, {interface, path}, %CachedPath{}, ttl)
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
    end
  end

  defp maybe_handle_cache_miss(context) do
    %{interface: interface, state: state} = context

    cache_miss =
      state.interfaces
      |> Map.get(interface)
      |> Core.Interface.maybe_handle_cache_miss(interface, state)

    case cache_miss do
      {:error, :interface_loading_failed} ->
        error = %{
          message: "Cannot load interface: #{interface}.",
          logger_metadata: [tag: "interface_loading_failed"],
          error_name: "interface_loading_failed"
        }

        Core.Error.handle_error(context, error)

      {:ok, descriptor, state} ->
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
    error = %{
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

      ok ->
        ok
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
end
