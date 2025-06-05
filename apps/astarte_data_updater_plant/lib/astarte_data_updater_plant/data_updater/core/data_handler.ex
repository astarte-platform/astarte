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
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
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
    with :ok <- validate_interface(interface),
         :ok <- validate_path(path),
         maybe_descriptor <- Map.get(state.interfaces, interface),
         {:ok, interface_descriptor, state} <-
           Core.Interface.maybe_handle_cache_miss(maybe_descriptor, interface, state),
         :ok <- can_write_on_interface?(interface_descriptor.ownership),
         interface_id <- interface_descriptor.interface_id,
         {:ok, mapping} <-
           Core.Interface.resolve_path(path, interface_descriptor, state.mappings),
         endpoint_id = mapping.endpoint_id,
         db_retention_policy = mapping.database_retention_policy,
         db_ttl = mapping.database_retention_ttl,
         {value, value_timestamp, _metadata} <-
           PayloadsDecoder.decode_bson_payload(payload, timestamp),
         expected_types <-
           Core.Interface.extract_expected_types(
             path,
             interface_descriptor,
             mapping,
             state.mappings
           ),
         :ok <- validate_value_type(expected_types, value) do
      device_id_string = Device.encode_device_id(state.device_id)

      maybe_explicit_value_timestamp =
        if mapping.explicit_timestamp do
          value_timestamp
        else
          div(timestamp, 10000)
        end

      Impl.execute_incoming_data_triggers(
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
        Impl.get_value_change_triggers(state, interface_id, endpoint_id, path, value)

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
          Impl.execute_pre_change_triggers(
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

          Impl.execute_device_error_triggers(
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

          Impl.execute_device_error_triggers(
            state,
            "unset_not_allowed",
            error_metadata,
            timestamp
          )

        :ok ->
          if has_change_triggers == :ok do
            :ok =
              Impl.execute_post_change_triggers(
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
    else
      {:error, :cannot_write_on_server_owned_interface} ->
        Logger.warning(
          "Tried to write on server owned interface: #{interface} on " <>
            "path: #{path}, base64-encoded payload: #{inspect(Base.encode64(payload))}, timestamp: #{inspect(timestamp)}.",
          tag: "write_on_server_owned_interface"
        )

        {:ok, state} = Core.Device.ask_clean_session(state, timestamp)
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

        Impl.execute_device_error_triggers(
          state,
          "write_on_server_owned_interface",
          error_metadata,
          timestamp
        )

        update_stats(state, interface, nil, path, payload)

      {:error, :invalid_interface} ->
        Logger.warning("Received invalid interface: #{inspect(interface)}.",
          tag: "invalid_interface"
        )

        {:ok, state} = Core.Device.ask_clean_session(state, timestamp)
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

        Impl.execute_device_error_triggers(
          state,
          "invalid_interface",
          error_metadata,
          timestamp
        )

        # We dont't update stats on an invalid interface
        state

      {:error, :invalid_path} ->
        Logger.warning("Received invalid path: #{inspect(path)}.", tag: "invalid_path")
        {:ok, state} = Core.Device.ask_clean_session(state, timestamp)
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

        Impl.execute_device_error_triggers(state, "invalid_path", error_metadata, timestamp)

        update_stats(state, interface, nil, path, payload)

      {:error, :mapping_not_found} ->
        Logger.warning("Mapping not found for #{interface}#{path}. Maybe outdated introspection?",
          tag: "mapping_not_found"
        )

        {:ok, state} = Core.Device.ask_clean_session(state, timestamp)
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

        Impl.execute_device_error_triggers(state, "mapping_not_found", error_metadata, timestamp)

        update_stats(state, interface, nil, path, payload)

      {:error, :interface_loading_failed} ->
        Logger.warning("Cannot load interface: #{interface}.", tag: "interface_loading_failed")
        # TODO: think about additional actions since the problem
        # could be a missing interface in the DB
        {:ok, state} = Core.Device.ask_clean_session(state, timestamp)
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

        Impl.execute_device_error_triggers(
          state,
          "interface_loading_failed",
          error_metadata,
          timestamp
        )

        update_stats(state, interface, nil, path, payload)

      {:guessed, _guessed_endpoints} ->
        Logger.warning("Mapping guessed for #{interface}#{path}. Maybe outdated introspection?",
          tag: "ambiguous_path"
        )

        {:ok, state} = Core.Device.ask_clean_session(state, timestamp)
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

        Impl.execute_device_error_triggers(
          state,
          "ambiguous_path",
          error_metadata,
          timestamp
        )

        update_stats(state, interface, nil, path, payload)

      {:error, :undecodable_bson_payload} ->
        Logger.warning(
          "Invalid BSON base64-encoded payload: #{inspect(Base.encode64(payload))} sent to #{interface}#{path}.",
          tag: "undecodable_bson_payload"
        )

        {:ok, state} = Core.Device.ask_clean_session(state, timestamp)
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

        Impl.execute_device_error_triggers(
          state,
          "undecodable_bson_payload",
          error_metadata,
          timestamp
        )

        update_stats(state, interface, nil, path, payload)

      {:error, :unexpected_value_type} ->
        Logger.warning(
          "Received invalid value: #{inspect(Base.encode64(payload))} sent to #{interface}#{path}.",
          tag: "unexpected_value_type"
        )

        {:ok, state} = Core.Device.ask_clean_session(state, timestamp)
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

        Impl.execute_device_error_triggers(
          state,
          "unexpected_value_type",
          error_metadata,
          timestamp
        )

        update_stats(state, interface, nil, path, payload)

      {:error, :value_size_exceeded} ->
        Logger.warning(
          "Received huge base64-encoded payload: #{inspect(Base.encode64(payload))} sent to #{interface}#{path}.",
          tag: "value_size_exceeded"
        )

        {:ok, state} = Core.Device.ask_clean_session(state, timestamp)
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

        Impl.execute_device_error_triggers(
          state,
          "value_size_exceeded",
          error_metadata,
          timestamp
        )

        update_stats(state, interface, nil, path, payload)

      {:error, :unexpected_object_key} ->
        base64_payload = Base.encode64(payload)

        Logger.warning(
          "Received object with unexpected key, object base64 is: #{base64_payload} sent to #{interface}#{path}.",
          tag: "unexpected_object_key"
        )

        {:ok, state} = Core.Device.ask_clean_session(state, timestamp)
        MessageTracker.discard(state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: state.realm}
        )

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        Impl.execute_device_error_triggers(
          state,
          "unexpected_object_key",
          error_metadata,
          timestamp
        )

        update_stats(state, interface, nil, path, payload)
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

  defp validate_interface(interface) do
    if String.valid?(interface),
      do: :ok,
      else: {:error, :invalid_interface}
  end

  defp validate_path(path) do
    cond do
      # Make sure the path is a valid unicode string
      not String.valid?(path) ->
        {:error, :invalid_path}

      # TODO: this is a temporary fix to work around a bug in EndpointsAutomaton.resolve_path/2
      String.contains?(path, "//") ->
        {:error, :invalid_path}

      true ->
        :ok
    end
  end

  defp can_write_on_interface?(:device), do: :ok
  defp can_write_on_interface?(:server), do: {:error, :cannot_write_on_server_owned_interface}

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

  defp update_stats(state, interface, major, path, payload) do
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
