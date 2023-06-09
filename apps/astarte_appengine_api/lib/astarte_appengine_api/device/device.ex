#
# This file is part of Astarte.
#
# Copyright 2017-2023 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Device do
  @moduledoc """
  The Device context.
  """
  alias Astarte.AppEngine.API.DataTransmitter
  alias Astarte.AppEngine.API.Device.AstarteValue
  alias Astarte.AppEngine.API.Device.DevicesListOptions
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.MapTree
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.API.Device.InterfaceValuesOptions
  alias Astarte.AppEngine.API.Device.Queries
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Interface.Aggregation
  alias Astarte.Core.Interface.Type
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Mappings
  alias Astarte.DataAccess.Device, as: DeviceQueries
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Ecto.Changeset
  require Logger

  def list_devices!(realm_name, params) do
    changeset = DevicesListOptions.changeset(%DevicesListOptions{}, params)

    with {:ok, options} <- Changeset.apply_action(changeset, :insert),
         {:ok, client} <- Database.connect(realm: realm_name) do
      Queries.retrieve_devices_list(client, options.limit, options.details, options.from_token)
    end
  end

  @doc """
  Returns a DeviceStatus struct which represents device status.
  Device status returns information such as connected, last_connection and last_disconnection.
  """
  def get_device_status!(realm_name, encoded_device_id) do
    with {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      Queries.retrieve_device_status(client, device_id)
    end
  end

  def merge_device_status(realm_name, encoded_device_id, device_status_merge) do
    with {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, device_status} <- Queries.retrieve_device_status(client, device_id),
         changeset = DeviceStatus.changeset(device_status, device_status_merge),
         {:ok, updated_device_status} <- Ecto.Changeset.apply_action(changeset, :update),
         credentials_inhibited_change = Map.get(changeset.changes, :credentials_inhibited),
         :ok <- change_credentials_inhibited(client, device_id, credentials_inhibited_change),
         aliases_change = Map.get(changeset.changes, :aliases, %{}),
         attributes_change = Map.get(changeset.changes, :attributes, %{}),
         :ok <- update_aliases(client, device_id, aliases_change),
         :ok <- update_attributes(client, device_id, attributes_change) do
      # Manually merge aliases since changesets don't perform maps deep merge
      merged_aliases = merge_data(device_status.aliases, updated_device_status.aliases)
      merged_attributes = merge_data(device_status.attributes, updated_device_status.attributes)

      updated_map =
        updated_device_status
        |> Map.put(:aliases, merged_aliases)
        |> Map.put(:attributes, merged_attributes)

      {:ok, updated_map}
    end
  end

  defp update_attributes(client, device_id, attributes) do
    Enum.reduce_while(attributes, :ok, fn
      {"", _attribute_value}, _acc ->
        Logger.warn("Attribute key cannot be an empty string.", tag: :invalid_attribute_empty_key)
        {:halt, {:error, :invalid_attributes}}

      {attribute_key, nil}, _acc ->
        case Queries.delete_attribute(client, device_id, attribute_key) do
          :ok ->
            {:cont, :ok}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end

      {attribute_key, attribute_value}, _acc ->
        case Queries.insert_attribute(client, device_id, attribute_key, attribute_value) do
          :ok ->
            {:cont, :ok}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end)
  end

  defp update_aliases(client, device_id, aliases) do
    Enum.reduce_while(aliases, :ok, fn
      {_alias_key, ""}, _acc ->
        Logger.warn("Alias value cannot be an empty string.", tag: :invalid_alias_empty_value)
        {:halt, {:error, :invalid_alias}}

      {"", _alias_value}, _acc ->
        Logger.warn("Alias key cannot be an empty string.", tag: :invalid_alias_empty_key)
        {:halt, {:error, :invalid_alias}}

      {alias_key, nil}, _acc ->
        case Queries.delete_alias(client, device_id, alias_key) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      {alias_key, alias_value}, _acc ->
        case Queries.insert_alias(client, device_id, alias_key, alias_value) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end

  defp merge_data(old_data, new_data) when is_map(old_data) and is_map(new_data) do
    Map.merge(old_data, new_data)
    |> Enum.reject(fn {_, v} -> v == nil end)
    |> Enum.into(%{})
  end

  defp change_credentials_inhibited(_client, _device_id, nil) do
    :ok
  end

  defp change_credentials_inhibited(client, device_id, credentials_inhibited)
       when is_boolean(credentials_inhibited) do
    Queries.set_inhibit_credentials_request(client, device_id, credentials_inhibited)
  end

  @doc """
  Returns the list of interfaces.
  """
  def list_interfaces(realm_name, encoded_device_id) do
    with {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      Queries.retrieve_interfaces_list(client, device_id)
    end
  end

  @doc """
  Gets all values set on a certain interface.
  This function handles all GET requests on /{realm_name}/devices/{device_id}/interfaces/{interface}
  """
  def get_interface_values!(realm_name, encoded_device_id, interface, params) do
    changeset = InterfaceValuesOptions.changeset(%InterfaceValuesOptions{}, params)

    with {:ok, options} <- Changeset.apply_action(changeset, :insert),
         {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <-
           DeviceQueries.interface_version(realm_name, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(realm_name, interface, major_version) do
      do_get_interface_values!(
        client,
        device_id,
        Aggregation.from_int(interface_row[:aggregation]),
        interface_row,
        options
      )
    end
  end

  @doc """
  Gets a single interface_values.

  Raises if the Interface values does not exist.
  """
  def get_interface_values!(realm_name, encoded_device_id, interface, no_prefix_path, params) do
    changeset = InterfaceValuesOptions.changeset(%InterfaceValuesOptions{}, params)

    with {:ok, options} <- Changeset.apply_action(changeset, :insert),
         {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <-
           DeviceQueries.interface_version(realm_name, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(realm_name, interface, major_version),
         path <- "/" <> no_prefix_path,
         {:ok, interface_descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         {:ok, endpoint_ids} <-
           get_endpoint_ids(interface_descriptor.automaton, path, allow_guess: true) do
      endpoint_query = Queries.prepare_value_type_query(interface_row[:interface_id])

      do_get_interface_values!(
        client,
        device_id,
        Aggregation.from_int(interface_row[:aggregation]),
        Type.from_int(interface_row[:type]),
        interface_row,
        endpoint_ids,
        endpoint_query,
        path,
        options
      )
    end
  end

  defp update_individual_interface_values(
         client,
         realm_name,
         device_id,
         interface_descriptor,
         path,
         raw_value
       ) do
    with {:ok, [endpoint_id]} <- get_endpoint_ids(interface_descriptor.automaton, path),
         mapping <-
           Queries.retrieve_mapping(client, interface_descriptor.interface_id, endpoint_id),
         {:ok, value} <- cast_value(mapping.value_type, raw_value),
         :ok <- validate_value_type(mapping.value_type, value),
         wrapped_value = wrap_to_bson_struct(mapping.value_type, value),
         interface_type = interface_descriptor.type,
         reliability = mapping.reliability,
         publish_opts = build_publish_opts(interface_type, reliability),
         interface_name = interface_descriptor.name,
         :ok <-
           ensure_publish(
             realm_name,
             device_id,
             interface_name,
             path,
             wrapped_value,
             publish_opts
           ),
         {:ok, realm_max_ttl} <-
           Queries.fetch_datastream_maximum_storage_retention(client) do
      timestamp_micro =
        DateTime.utc_now()
        |> DateTime.to_unix(:microsecond)

      db_max_ttl =
        if mapping.database_retention_policy == :use_ttl do
          min(realm_max_ttl, mapping.database_retention_ttl)
        else
          realm_max_ttl
        end

      opts =
        case db_max_ttl do
          nil ->
            []

          _ ->
            [ttl: db_max_ttl]
        end

      Queries.insert_value_into_db(
        client,
        device_id,
        interface_descriptor,
        endpoint_id,
        mapping,
        path,
        value,
        timestamp_micro,
        opts
      )

      if interface_descriptor.type == :datastream do
        Queries.insert_path_into_db(
          client,
          device_id,
          interface_descriptor,
          endpoint_id,
          path,
          timestamp_micro,
          div(timestamp_micro, 1000),
          opts
        )
      end

      {:ok,
       %InterfaceValues{
         data: raw_value
       }}
    else
      {:error, :endpoint_guess_not_allowed} ->
        _ = Logger.warn("Incomplete path not allowed.", tag: "endpoint_guess_not_allowed")
        {:error, :read_only_resource}

      {:error, :unexpected_value_type, expected: value_type} ->
        _ = Logger.warn("Unexpected value type.", tag: "unexpected_value_type")
        {:error, :unexpected_value_type, expected: value_type}

      {:error, reason} ->
        _ = Logger.warn("Error while writing to interface.", tag: "write_to_device_error")
        {:error, reason}
    end
  end

  defp path_or_endpoint_depth(path) when is_binary(path) do
    String.split(path, "/", trim: true)
    |> length()
  end

  defp resolve_object_aggregation_path(
         path,
         %InterfaceDescriptor{aggregation: :object} = interface_descriptor,
         mappings
       ) do
    mappings =
      Enum.into(mappings, %{}, fn mapping ->
        {mapping.endpoint_id, mapping}
      end)

    with {:guessed, guessed_endpoints} <-
           EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton),
         :ok <- check_object_aggregation_prefix(path, guessed_endpoints, mappings) do
      endpoint_id =
        CQLUtils.endpoint_id(
          interface_descriptor.name,
          interface_descriptor.major_version,
          ""
        )

      {:ok, %Mapping{endpoint_id: endpoint_id}}
    else
      {:ok, _endpoint_id} ->
        # This is invalid here, publish doesn't happen on endpoints in object aggregated interfaces
        Logger.warn(
          "Tried to publish on endpoint #{inspect(path)} for object aggregated " <>
            "interface #{inspect(interface_descriptor.name)}. You should publish on " <>
            "the common prefix",
          tag: "invalid_path"
        )

        {:error, :mapping_not_found}

      {:error, :not_found} ->
        Logger.warn(
          "Tried to publish on invalid path #{inspect(path)} for object aggregated " <>
            "interface #{inspect(interface_descriptor.name)}",
          tag: "invalid_path"
        )

        {:error, :mapping_not_found}

      {:error, :invalid_object_aggregation_path} ->
        Logger.warn(
          "Tried to publish on invalid path #{inspect(path)} for object aggregated " <>
            "interface #{inspect(interface_descriptor.name)}",
          tag: "invalid_path"
        )

        {:error, :mapping_not_found}
    end
  end

  defp check_object_aggregation_prefix(path, guessed_endpoints, mappings) do
    received_path_depth = path_or_endpoint_depth(path)

    Enum.reduce_while(guessed_endpoints, :ok, fn
      endpoint_id, _acc ->
        with {:ok, %Mapping{endpoint: endpoint}} <- Map.fetch(mappings, endpoint_id),
             endpoint_depth when received_path_depth == endpoint_depth - 1 <-
               path_or_endpoint_depth(endpoint) do
          {:cont, :ok}
        else
          _ ->
            {:halt, {:error, :invalid_object_aggregation_path}}
        end
    end)
  end

  defp object_retention([first | _rest] = _mappings) do
    if first.database_retention_policy == :no_ttl do
      nil
    else
      first.database_retention_ttl
    end
  end

  defp update_object_interface_values(
         client,
         realm_name,
         device_id,
         interface_descriptor,
         path,
         raw_value
       ) do
    timestamp_micro =
      DateTime.utc_now()
      |> DateTime.to_unix(:microsecond)

    with {:ok, mappings} <-
           Mappings.fetch_interface_mappings(realm_name, interface_descriptor.interface_id),
         {:ok, endpoint} <-
           resolve_object_aggregation_path(path, interface_descriptor, mappings),
         endpoint_id <- endpoint.endpoint_id,
         expected_types <- extract_expected_types(mappings),
         {:ok, value} <- cast_value(expected_types, raw_value),
         :ok <- validate_value_type(expected_types, value),
         wrapped_value = wrap_to_bson_struct(nil, value),
         reliability = extract_aggregate_reliability(mappings),
         interface_type = interface_descriptor.type,
         publish_opts = build_publish_opts(interface_type, reliability),
         interface_name = interface_descriptor.name,
         :ok <-
           ensure_publish(
             realm_name,
             device_id,
             interface_name,
             path,
             wrapped_value,
             publish_opts
           ),
         {:ok, realm_max_ttl} <-
           Queries.fetch_datastream_maximum_storage_retention(client) do
      db_max_ttl = min(realm_max_ttl, object_retention(mappings))

      opts =
        case db_max_ttl do
          nil ->
            []

          _ ->
            [ttl: db_max_ttl]
        end

      Queries.insert_value_into_db(
        client,
        device_id,
        interface_descriptor,
        nil,
        nil,
        path,
        value,
        timestamp_micro,
        opts
      )

      Queries.insert_path_into_db(
        client,
        device_id,
        interface_descriptor,
        endpoint_id,
        path,
        timestamp_micro,
        div(timestamp_micro, 1000),
        opts
      )

      {:ok,
       %InterfaceValues{
         data: raw_value
       }}
    else
      {:error, :unexpected_value_type, expected: value_type} ->
        Logger.warn("Unexpected value type.", tag: "unexpected_value_type")
        {:error, :unexpected_value_type, expected: value_type}

      {:error, :invalid_object_aggregation_path} ->
        Logger.warn("Error while trying to publish on path for object aggregated interface.",
          tag: "invalid_object_aggregation_path"
        )

        {:error, :invalid_object_aggregation_path}

      {:error, :mapping_not_found} ->
        {:error, :mapping_not_found}

      {:error, :database_error} ->
        Logger.warn("Error while trying to retrieve ttl.", tag: "database_error")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Unhandled error while updating object interface values: #{inspect(reason)}.")

        {:error, reason}
    end
  end

  def update_interface_values(
        realm_name,
        encoded_device_id,
        interface,
        no_prefix_path,
        raw_value,
        _params
      ) do
    with {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <-
           DeviceQueries.interface_version(realm_name, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(realm_name, interface, major_version),
         {:ok, interface_descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         {:ownership, :server} <- {:ownership, interface_descriptor.ownership},
         path <- "/" <> no_prefix_path do
      if interface_descriptor.aggregation == :individual do
        update_individual_interface_values(
          client,
          realm_name,
          device_id,
          interface_descriptor,
          path,
          raw_value
        )
      else
        update_object_interface_values(
          client,
          realm_name,
          device_id,
          interface_descriptor,
          path,
          raw_value
        )
      end
    else
      {:ownership, :device} ->
        _ = Logger.warn("Invalid write (device owned).", tag: "cannot_write_to_device_owned")
        {:error, :cannot_write_to_device_owned}

      {:error, reason} ->
        _ = Logger.warn("Error while writing to interface.", tag: "write_to_device_error")
        {:error, reason}
    end
  end

  defp extract_expected_types(mappings) do
    Enum.into(mappings, %{}, fn mapping ->
      expected_key =
        mapping.endpoint
        |> String.split("/")
        |> List.last()

      {expected_key, mapping.value_type}
    end)
  end

  defp extract_aggregate_reliability([mapping | _rest] = _mappings) do
    # Extract the reliability from the first mapping since it's
    # the same for all mappings in object aggregated interfaces
    mapping.reliability
  end

  defp build_publish_opts(:properties, _reliability) do
    [type: :properties]
  end

  defp build_publish_opts(:datastream, reliability) do
    [type: :datastream, reliability: reliability]
  end

  defp ensure_publish(realm, device_id, interface, path, value, opts) do
    with {:ok, %{local_matches: local_matches, remote_matches: remote_matches}} <-
           publish_data(realm, device_id, interface, path, value, opts),
         :ok <- ensure_publish_reliability(local_matches, remote_matches, opts) do
      :ok
    end
  end

  defp publish_data(realm, device_id, interface, path, value, opts) do
    case Keyword.fetch!(opts, :type) do
      :properties ->
        DataTransmitter.set_property(
          realm,
          device_id,
          interface,
          path,
          value
        )

      :datastream ->
        qos =
          Keyword.fetch!(opts, :reliability)
          |> reliability_to_qos()

        DataTransmitter.push_datastream(
          realm,
          device_id,
          interface,
          path,
          value,
          qos: qos
        )
    end
  end

  # Exactly one match, always good
  defp ensure_publish_reliability(local_matches, remote_matches, _opts)
       when local_matches + remote_matches == 1 do
    :ok
  end

  # Multiple matches, we print a warning but we consider it ok
  defp ensure_publish_reliability(local_matches, remote_matches, _opts)
       when local_matches + remote_matches > 1 do
    Logger.warn(
      "Multiple matches while publishing to device, " <>
        "local_matches: #{local_matches}, remote_matches: #{remote_matches}",
      tag: "publish_multiple_matches"
    )

    :ok
  end

  # No matches, check type and reliability
  defp ensure_publish_reliability(_local, _remote, opts) do
    type = Keyword.fetch!(opts, :type)
    # We use get since we can be in a properties case
    reliability = Keyword.get(opts, :reliability)

    cond do
      type == :properties ->
        # No matches will happen only if the device doesn't have a session on
        # the broker, but the SDK would then send an emptyCache at the first
        # connection and receive all properties. Hence, we return :ok for
        # properties even if there are no matches
        :ok

      type == :datastream and reliability == :unreliable ->
        # Unreliable datastream is allowed to fail
        :ok

      true ->
        {:error, :cannot_push_to_device}
    end
  end

  defp reliability_to_qos(reliability) do
    case reliability do
      :unreliable -> 0
      :guaranteed -> 1
      :unique -> 2
    end
  end

  defp validate_value_type(expected_types, object)
       when is_map(expected_types) and is_map(object) do
    Enum.reduce_while(object, :ok, fn {key, value}, _acc ->
      with {:ok, expected_type} <- Map.fetch(expected_types, key),
           :ok <- validate_value_type(expected_type, value) do
        {:cont, :ok}
      else
        {:error, reason, expected} ->
          {:halt, {:error, reason, expected}}

        :error ->
          {:halt, {:error, :unexpected_object_key}}
      end
    end)
  end

  defp validate_value_type(value_type, value) do
    with :ok <- ValueType.validate_value(value_type, value) do
      :ok
    else
      {:error, :unexpected_value_type} ->
        {:error, :unexpected_value_type, expected: value_type}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cast_value(expected_types, object) when is_map(expected_types) and is_map(object) do
    Enum.reduce_while(object, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, expected_type} <- Map.fetch(expected_types, key),
           {:ok, normalized_value} <- cast_value(expected_type, value) do
        {:cont, {:ok, Map.put(acc, key, normalized_value)}}
      else
        {:error, reason, expected} ->
          {:halt, {:error, reason, expected}}

        :error ->
          {:halt, {:error, :unexpected_object_key}}
      end
    end)
  end

  defp cast_value(:datetime, value) when is_binary(value) do
    with {:ok, datetime, _utc_off} <- DateTime.from_iso8601(value) do
      {:ok, datetime}
    else
      {:error, _reason} ->
        {:error, :unexpected_value_type, expected: :datetime}
    end
  end

  defp cast_value(:datetime, value) when is_integer(value) do
    with {:ok, datetime} <- DateTime.from_unix(value, :millisecond) do
      {:ok, datetime}
    else
      {:error, _reason} ->
        {:error, :unexpected_value_type, expected: :datetime}
    end
  end

  defp cast_value(:datetime, _value) do
    {:error, :unexpected_value_type, expected: :datetime}
  end

  defp cast_value(:binaryblob, value) when is_binary(value) do
    with {:ok, binvalue} <- Base.decode64(value) do
      {:ok, binvalue}
    else
      :error ->
        {:error, :unexpected_value_type, expected: :binaryblob}
    end
  end

  defp cast_value(:binaryblob, _value) do
    {:error, :unexpected_value_type, expected: :binaryblob}
  end

  defp cast_value(:datetimearray, values) do
    case map_while_ok(values, &cast_value(:datetime, &1)) do
      {:ok, mapped_values} ->
        {:ok, mapped_values}

      _ ->
        {:error, :unexpected_value_type, expected: :datetimearray}
    end
  end

  defp cast_value(:binaryblobarray, values) do
    case map_while_ok(values, &cast_value(:binaryblob, &1)) do
      {:ok, mapped_values} ->
        {:ok, mapped_values}

      _ ->
        {:error, :unexpected_value_type, expected: :binaryblobarray}
    end
  end

  defp cast_value(_anytype, anyvalue) do
    {:ok, anyvalue}
  end

  defp map_while_ok(values, fun) when is_list(values) do
    result =
      Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
        case fun.(value) do
          {:ok, mapped_value} ->
            {:cont, {:ok, [mapped_value | acc]}}

          other ->
            {:halt, other}
        end
      end)

    with {:ok, mapped_values} <- result do
      {:ok, Enum.reverse(mapped_values)}
    end
  end

  defp map_while_ok(not_list_values, _fun) do
    {:error, :values_is_not_a_list}
  end

  defp wrap_to_bson_struct(:binaryblob, value) do
    # 0 is generic binary subtype
    {0, value}
  end

  defp wrap_to_bson_struct(:binaryblobarray, values) do
    Enum.map(values, &wrap_to_bson_struct(:binaryblob, &1))
  end

  defp wrap_to_bson_struct(_anytype, value) do
    value
  end

  # TODO: we should probably allow delete for every path regardless of the interface type
  # just for maintenance reasons
  def delete_interface_values(realm_name, encoded_device_id, interface, no_prefix_path) do
    with {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <-
           DeviceQueries.interface_version(realm_name, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(realm_name, interface, major_version),
         {:ok, interface_descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         {:ownership, :server} <- {:ownership, interface_descriptor.ownership},
         path <- "/" <> no_prefix_path,
         {:ok, [endpoint_id]} <- get_endpoint_ids(interface_descriptor.automaton, path) do
      mapping = Queries.retrieve_mapping(client, interface_descriptor.interface_id, endpoint_id)

      Queries.insert_value_into_db(
        client,
        device_id,
        interface_descriptor,
        endpoint_id,
        mapping,
        path,
        nil,
        nil,
        []
      )

      case interface_descriptor.type do
        :properties ->
          unset_property(realm_name, device_id, interface, path)

        :datastream ->
          :ok
      end
    else
      {:ownership, :device} ->
        {:error, :cannot_write_to_device_owned}

      {:error, :endpoint_guess_not_allowed} ->
        {:error, :read_only_resource}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp unset_property(realm_name, device_id, interface, path) do
    # Do not check for matches, as the device receives the unset information anyway
    # (either when it reconnects or in the /control/consumerProperties message).
    # See https://github.com/astarte-platform/astarte/issues/640
    with {:ok, _} <- DataTransmitter.unset_property(realm_name, device_id, interface, path) do
      :ok
    end
  end

  defp do_get_interface_values!(client, device_id, :individual, interface_row, opts) do
    endpoint_rows =
      Queries.retrieve_all_endpoint_ids_for_interface!(client, interface_row[:interface_id])

    values_map =
      Enum.reduce(endpoint_rows, %{}, fn endpoint_row, values ->
        # TODO: we can do this by using just one query without any filter on the endpoint
        value =
          retrieve_endpoint_values(
            client,
            device_id,
            Aggregation.from_int(interface_row[:aggregation]),
            Type.from_int(interface_row[:type]),
            interface_row,
            endpoint_row[:endpoint_id],
            endpoint_row,
            "/",
            opts
          )

        Map.merge(values, value)
      end)

    {:ok, %InterfaceValues{data: MapTree.inflate_tree(values_map)}}
  end

  defp do_get_interface_values!(client, device_id, :object, interface_row, opts) do
    # We need to know if mappings have explicit_timestamp set, so we retrieve it from the
    # first one.
    endpoint =
      Queries.retrieve_all_endpoint_ids_for_interface!(client, interface_row[:interface_id])
      |> CQEx.Result.head()

    mapping =
      Queries.retrieve_mapping(client, interface_row[:interface_id], endpoint[:endpoint_id])

    do_get_interface_values!(
      client,
      device_id,
      Aggregation.from_int(interface_row[:aggregation]),
      Type.from_int(interface_row[:type]),
      interface_row,
      nil,
      nil,
      "/",
      %{opts | explicit_timestamp: mapping.explicit_timestamp}
    )
  end

  defp do_get_interface_values!(
         client,
         device_id,
         :individual,
         :properties,
         interface_row,
         endpoint_ids,
         endpoint_query,
         path,
         opts
       ) do
    result =
      List.foldl(endpoint_ids, %{}, fn endpoint_id, values ->
        endpoint_row = Queries.execute_value_type_query(client, endpoint_query, endpoint_id)

        value =
          retrieve_endpoint_values(
            client,
            device_id,
            :individual,
            :properties,
            interface_row,
            endpoint_id,
            endpoint_row,
            path,
            opts
          )

        Map.merge(values, value)
      end)

    individual_value = Map.get(result, "")

    data =
      if individual_value != nil do
        individual_value
      else
        MapTree.inflate_tree(result)
      end

    {:ok, %InterfaceValues{data: data}}
  end

  defp do_get_interface_values!(
         client,
         device_id,
         :individual,
         :datastream,
         interface_row,
         endpoint_ids,
         endpoint_query,
         path,
         opts
       ) do
    [endpoint_id] = endpoint_ids

    endpoint_row = Queries.execute_value_type_query(client, endpoint_query, endpoint_id)

    retrieve_endpoint_values(
      client,
      device_id,
      :individual,
      :datastream,
      interface_row,
      endpoint_id,
      endpoint_row,
      path,
      opts
    )
  end

  defp do_get_interface_values!(
         client,
         device_id,
         :object,
         :datastream,
         interface_row,
         _endpoint_ids,
         _endpoint_query,
         path,
         opts
       ) do
    # We need to know if mappings have explicit_timestamp set, so we retrieve it from the
    # first one.
    endpoint =
      Queries.retrieve_all_endpoint_ids_for_interface!(client, interface_row[:interface_id])
      |> CQEx.Result.head()

    mapping =
      Queries.retrieve_mapping(client, interface_row[:interface_id], endpoint[:endpoint_id])

    endpoint_rows =
      Queries.retrieve_all_endpoints_for_interface!(client, interface_row[:interface_id])

    interface_values =
      retrieve_endpoint_values(
        client,
        device_id,
        :object,
        :datastream,
        interface_row,
        nil,
        endpoint_rows,
        path,
        %{opts | explicit_timestamp: mapping.explicit_timestamp}
      )

    cond do
      path == "/" and interface_values == {:error, :path_not_found} ->
        {:ok, %InterfaceValues{data: %{}}}

      path != "/" and elem(interface_values, 1).data == [] ->
        {:error, :path_not_found}

      true ->
        interface_values
    end
  end

  # TODO: optimize: do not use string replace
  defp simplify_path(base_path, path) do
    no_basepath = String.replace_prefix(path, base_path, "")

    case no_basepath do
      "/" <> noleadingslash -> noleadingslash
      already_noleadingslash -> already_noleadingslash
    end
  end

  defp get_endpoint_ids(automaton, path, opts \\ []) do
    allow_guess = opts[:allow_guess]

    case EndpointsAutomaton.resolve_path(path, automaton) do
      {:ok, endpoint_id} ->
        {:ok, [endpoint_id]}

      {:guessed, endpoint_ids} when allow_guess ->
        {:ok, endpoint_ids}

      {:guessed, _endpoint_ids} ->
        {:error, :endpoint_guess_not_allowed}

      {:error, :not_found} ->
        {:error, :endpoint_not_found}
    end
  end

  defp column_pretty_name(endpoint) do
    endpoint
    |> String.split("/")
    |> List.last()
  end

  defp retrieve_endpoint_values(
         client,
         device_id,
         :individual,
         :datastream,
         interface_row,
         endpoint_id,
         endpoint_row,
         "/",
         opts
       ) do
    path = "/"

    interface_id = interface_row[:interface_id]

    values =
      Queries.retrieve_all_endpoint_paths!(client, device_id, interface_id, endpoint_id)
      |> Enum.reduce(%{}, fn row, values_map ->
        if String.starts_with?(row[:path], path) do
          [{:path, row_path}] = row

          last_value =
            Queries.last_datastream_value!(
              client,
              device_id,
              interface_row,
              endpoint_row,
              endpoint_id,
              row_path,
              opts
            )

          case last_value do
            :empty_dataset ->
              %{}

            [
              {:value_timestamp, tstamp},
              {:reception_timestamp, reception},
              _,
              {_, v}
            ] ->
              simplified_path = simplify_path(path, row_path)

              nice_value =
                AstarteValue.to_json_friendly(
                  v,
                  ValueType.from_int(endpoint_row[:value_type]),
                  fetch_biginteger_opts_or_default(opts)
                )

              Map.put(values_map, simplified_path, %{
                "value" => nice_value,
                "timestamp" =>
                  AstarteValue.to_json_friendly(
                    tstamp,
                    :datetime,
                    keep_milliseconds: opts.keep_milliseconds
                  ),
                "reception_timestamp" =>
                  AstarteValue.to_json_friendly(
                    reception,
                    :datetime,
                    keep_milliseconds: opts.keep_milliseconds
                  )
              })
          end
        else
          values_map
        end
      end)

    values
  end

  defp retrieve_endpoint_values(
         client,
         device_id,
         :object,
         :datastream,
         interface_row,
         nil,
         endpoint_row,
         "/",
         opts
       ) do
    path = "/"

    interface_id = interface_row[:interface_id]

    endpoint_id = CQLUtils.endpoint_id(interface_row[:name], interface_row[:major_version], "")

    {count, paths} =
      Queries.retrieve_all_endpoint_paths!(client, device_id, interface_id, endpoint_id)
      |> Enum.reduce({0, []}, fn row, {count, all_paths} ->
        if String.starts_with?(row[:path], path) do
          [{:path, row_path}] = row

          {count + 1, [row_path | all_paths]}
        else
          {count, all_paths}
        end
      end)

    cond do
      count == 0 ->
        {:error, :path_not_found}

      count == 1 ->
        [only_path] = paths

        with {:ok,
              %Astarte.AppEngine.API.Device.InterfaceValues{data: values, metadata: metadata}} <-
               retrieve_endpoint_values(
                 client,
                 device_id,
                 :object,
                 :datastream,
                 interface_row,
                 endpoint_id,
                 endpoint_row,
                 only_path,
                 opts
               ),
             {:ok, interface_values} <-
               get_interface_values_from_path(values, metadata, path, only_path) do
          {:ok, interface_values}
        else
          err ->
            Logger.warn("An error occurred while retrieving endpoint values: #{inspect(err)}",
              tag: "retrieve_endpoint_values_error"
            )

            err
        end

      count > 1 ->
        values_map =
          Enum.reduce(paths, %{}, fn a_path, values_map ->
            {:ok, %Astarte.AppEngine.API.Device.InterfaceValues{data: values}} =
              retrieve_endpoint_values(
                client,
                device_id,
                :object,
                :datastream,
                interface_row,
                endpoint_id,
                endpoint_row,
                a_path,
                %{opts | limit: 1}
              )

            case values do
              [] ->
                values_map

              [value] ->
                simplified_path = simplify_path(path, a_path)

                Map.put(values_map, simplified_path, value)
            end
          end)
          |> MapTree.inflate_tree()

        {:ok, %InterfaceValues{data: values_map}}
    end
  end

  defp retrieve_endpoint_values(
         client,
         device_id,
         :object,
         :datastream,
         interface_row,
         _endpoint_id,
         endpoint_rows,
         path,
         opts
       ) do
    # FIXME: reading result wastes atoms: new atoms are allocated every time a new table is seen
    # See cqerl_protocol.erl:330 (binary_to_atom), strings should be used when dealing with large schemas
    {columns, column_metadata, downsample_column_atom} =
      Enum.reduce(endpoint_rows, {"", %{}, nil}, fn endpoint,
                                                    {query_acc, atoms_map,
                                                     prev_downsample_column_atom} ->
        endpoint_name = endpoint[:endpoint]
        column_name = CQLUtils.endpoint_to_db_column_name(endpoint_name)

        value_type = endpoint[:value_type] |> ValueType.from_int()

        next_query_acc = "#{query_acc} #{column_name}, "
        column_atom = String.to_atom(column_name)
        pretty_name = column_pretty_name(endpoint_name)

        metadata = %{pretty_name: pretty_name, value_type: value_type}
        next_atom_map = Map.put(atoms_map, column_atom, metadata)

        if opts.downsample_key == pretty_name do
          {next_query_acc, next_atom_map, column_atom}
        else
          {next_query_acc, next_atom_map, prev_downsample_column_atom}
        end
      end)

    {:ok, count, values} =
      Queries.retrieve_object_datastream_values(
        client,
        device_id,
        interface_row,
        path,
        columns,
        opts
      )

    values
    |> maybe_downsample_to(count, :object, %InterfaceValuesOptions{
      opts
      | downsample_key: downsample_column_atom
    })
    |> pack_result(:object, :datastream, column_metadata, opts)
  end

  defp retrieve_endpoint_values(
         client,
         device_id,
         :individual,
         :datastream,
         interface_row,
         endpoint_id,
         endpoint_row,
         path,
         opts
       ) do
    {:ok, count, values} =
      Queries.retrieve_datastream_values(
        client,
        device_id,
        interface_row,
        endpoint_row,
        endpoint_id,
        path,
        opts
      )

    values
    |> maybe_downsample_to(count, :individual, opts)
    |> pack_result(:individual, :datastream, endpoint_row, path, opts)
  end

  defp retrieve_endpoint_values(
         client,
         device_id,
         :individual,
         :properties,
         interface_row,
         endpoint_id,
         endpoint_row,
         path,
         opts
       ) do
    values =
      Queries.all_properties_for_endpoint!(
        client,
        device_id,
        interface_row,
        endpoint_row,
        endpoint_id
      )
      |> Enum.reduce(%{}, fn row, values_map ->
        if String.starts_with?(row[:path], path) do
          [{:path, row_path}, {_, row_value}] = row

          simplified_path = simplify_path(path, row_path)

          nice_value =
            AstarteValue.to_json_friendly(
              row_value,
              ValueType.from_int(endpoint_row[:value_type]),
              fetch_biginteger_opts_or_default(opts)
            )

          Map.put(values_map, simplified_path, nice_value)
        else
          values_map
        end
      end)

    values
  end

  defp get_interface_values_from_path([], _metadata, _path, _only_path) do
    {:ok, %InterfaceValues{data: %{}}}
  end

  defp get_interface_values_from_path(values, metadata, path, only_path) when is_list(values) do
    simplified_path = simplify_path(path, only_path)

    case simplified_path do
      "" ->
        {:ok, %InterfaceValues{data: values, metadata: metadata}}

      _ ->
        values_map =
          %{simplified_path => values}
          |> MapTree.inflate_tree()

        {:ok, %InterfaceValues{data: values_map, metadata: metadata}}
    end
  end

  defp get_interface_values_from_path(values, metadata, _path, _only_path) do
    {:ok, %InterfaceValues{data: values, metadata: metadata}}
  end

  defp maybe_downsample_to(values, _count, _aggregation, %InterfaceValuesOptions{
         downsample_to: nil
       }) do
    values
  end

  defp maybe_downsample_to(values, nil, _aggregation, _opts) do
    # TODO: we can't downsample an object without a valid count, propagate an error changeset
    # when we start using changeset consistently here
    _ = Logger.warn("No valid count in maybe_downsample_to.", tag: "downsample_invalid_count")
    values
  end

  defp maybe_downsample_to(values, _count, :object, %InterfaceValuesOptions{downsample_key: nil}) do
    # TODO: we can't downsample an object without downsample_key, propagate an error changeset
    # when we start using changeset consistently here
    _ =
      Logger.warn("No valid downsample_key found in maybe_downsample_to.",
        tag: "downsample_invalid_key"
      )

    values
  end

  defp maybe_downsample_to(values, count, :object, %InterfaceValuesOptions{
         downsample_to: downsampled_size,
         downsample_key: downsample_key,
         explicit_timestamp: explicit_timestamp
       })
       when downsampled_size > 2 do
    timestamp_column =
      if explicit_timestamp do
        :value_timestamp
      else
        :reception_timestamp
      end

    avg_bucket_size = max(1, (count - 2) / (downsampled_size - 2))

    sample_to_x_fun = fn sample -> Keyword.get(sample, timestamp_column) end
    sample_to_y_fun = fn sample -> Keyword.get(sample, downsample_key) end
    xy_to_sample_fun = fn x, y -> [{timestamp_column, x}, {downsample_key, y}] end

    ExLTTB.Stream.downsample(
      values,
      avg_bucket_size,
      sample_to_x_fun: sample_to_x_fun,
      sample_to_y_fun: sample_to_y_fun,
      xy_to_sample_fun: xy_to_sample_fun
    )
  end

  defp maybe_downsample_to(values, count, :individual, %InterfaceValuesOptions{
         downsample_to: downsampled_size
       })
       when downsampled_size > 2 do
    avg_bucket_size = max(1, (count - 2) / (downsampled_size - 2))

    sample_to_x_fun = fn sample -> Keyword.get(sample, :value_timestamp) end

    sample_to_y_fun = fn sample ->
      timestamp_keys = [:value_timestamp, :reception_timestamp, :reception_timestamp_submillis]
      [{_key, value}] = Keyword.drop(sample, timestamp_keys)
      value
    end

    xy_to_sample_fun = fn x, y -> [{:value_timestamp, x}, {:generic_key, y}] end

    ExLTTB.Stream.downsample(
      values,
      avg_bucket_size,
      sample_to_x_fun: sample_to_x_fun,
      sample_to_y_fun: sample_to_y_fun,
      xy_to_sample_fun: xy_to_sample_fun
    )
  end

  defp pack_result(
         values,
         :individual,
         :datastream,
         endpoint_row,
         _path,
         %{format: "structured"} = opts
       ) do
    values_array =
      for value <- values do
        [{:value_timestamp, tstamp}, _, _, {_, v}] = value

        %{
          "timestamp" =>
            AstarteValue.to_json_friendly(
              tstamp,
              :datetime,
              keep_milliseconds: opts.keep_milliseconds
            ),
          "value" =>
            AstarteValue.to_json_friendly(v, ValueType.from_int(endpoint_row[:value_type]), [])
        }
      end

    if values_array != [] do
      {:ok,
       %InterfaceValues{
         data: values_array
       }}
    else
      {:error, :path_not_found}
    end
  end

  defp pack_result(
         values,
         :individual,
         :datastream,
         endpoint_row,
         path,
         %{format: "table"} = opts
       ) do
    value_name =
      path
      |> String.split("/")
      |> List.last()

    values_array =
      for value <- values do
        [{:value_timestamp, tstamp}, _, _, {_, v}] = value

        [
          AstarteValue.to_json_friendly(tstamp, :datetime, []),
          AstarteValue.to_json_friendly(
            v,
            ValueType.from_int(endpoint_row[:value_type]),
            keep_milliseconds: opts.keep_milliseconds
          )
        ]
      end

    if values_array != [] do
      {:ok,
       %InterfaceValues{
         metadata: %{
           "columns" => %{"timestamp" => 0, value_name => 1},
           "table_header" => ["timestamp", value_name]
         },
         data: values_array
       }}
    else
      {:error, :path_not_found}
    end
  end

  defp pack_result(
         values,
         :individual,
         :datastream,
         endpoint_row,
         _path,
         %{format: "disjoint_tables"} = opts
       ) do
    values_array =
      for value <- values do
        [{:value_timestamp, tstamp}, _, _, {_, v}] = value

        [
          AstarteValue.to_json_friendly(v, ValueType.from_int(endpoint_row[:value_type]), []),
          AstarteValue.to_json_friendly(
            tstamp,
            :datetime,
            keep_milliseconds: opts.keep_milliseconds
          )
        ]
      end

    if values_array != [] do
      {:ok,
       %InterfaceValues{
         data: %{"value" => values_array}
       }}
    else
      {:error, :path_not_found}
    end
  end

  defp pack_result(
         values,
         :object,
         :datastream,
         column_metadata,
         %{format: "table"} = opts
       ) do
    timestamp_column =
      if opts.explicit_timestamp do
        :value_timestamp
      else
        :reception_timestamp
      end

    {_cols_count, columns, reverse_table_header} =
      Queries.first_result_row(values)
      |> List.foldl({1, %{"timestamp" => 0}, ["timestamp"]}, fn {column, _column_value},
                                                                {next_index, acc, list_acc} ->
        pretty_name = column_metadata[column][:pretty_name]

        if pretty_name != nil and pretty_name != "timestamp" do
          {next_index + 1, Map.put(acc, pretty_name, next_index), [pretty_name | list_acc]}
        else
          {next_index, acc, list_acc}
        end
      end)

    table_header = Enum.reverse(reverse_table_header)

    values_array =
      for value <- values do
        base_array_entry = [
          AstarteValue.to_json_friendly(
            value[timestamp_column],
            :datetime,
            keep_milliseconds: opts.keep_milliseconds
          )
        ]

        List.foldl(value, base_array_entry, fn {column, column_value}, acc ->
          case Map.fetch(column_metadata, column) do
            {:ok, metadata} ->
              %{
                value_type: value_type
              } = metadata

              json_friendly_value = AstarteValue.to_json_friendly(column_value, value_type, [])

              [json_friendly_value | acc]

            :error ->
              acc
          end
        end)
        |> Enum.reverse()
      end

    {:ok,
     %InterfaceValues{
       metadata: %{"columns" => columns, "table_header" => table_header},
       data: values_array
     }}
  end

  defp pack_result(
         values,
         :object,
         :datastream,
         column_metadata,
         %{format: "disjoint_tables"} = opts
       ) do
    timestamp_column =
      if opts.explicit_timestamp do
        :value_timestamp
      else
        :reception_timestamp
      end

    reversed_columns_map =
      Enum.reduce(values, %{}, fn value, columns_acc ->
        List.foldl(value, columns_acc, fn {column, column_value}, acc ->
          case Map.fetch(column_metadata, column) do
            {:ok, metadata} ->
              %{
                pretty_name: pretty_name,
                value_type: value_type
              } = metadata

              json_friendly_value = AstarteValue.to_json_friendly(column_value, value_type, [])

              column_list = [
                [
                  json_friendly_value,
                  AstarteValue.to_json_friendly(
                    value[timestamp_column],
                    :datetime,
                    keep_milliseconds: opts.keep_milliseconds
                  )
                ]
                | Map.get(columns_acc, pretty_name, [])
              ]

              Map.put(acc, pretty_name, column_list)

            :error ->
              acc
          end
        end)
      end)

    columns =
      Enum.reduce(reversed_columns_map, %{}, fn {column_name, column_values}, acc ->
        Map.put(acc, column_name, Enum.reverse(column_values))
      end)

    {:ok,
     %InterfaceValues{
       data: columns
     }}
  end

  defp pack_result(
         values,
         :object,
         :datastream,
         column_metadata,
         %{format: "structured"} = opts
       ) do
    timestamp_column =
      if opts.explicit_timestamp do
        :value_timestamp
      else
        :reception_timestamp
      end

    values_list =
      for value <- values do
        base_array_entry = %{
          "timestamp" =>
            AstarteValue.to_json_friendly(
              value[timestamp_column],
              :datetime,
              keep_milliseconds: opts.keep_milliseconds
            )
        }

        List.foldl(value, base_array_entry, fn {column, column_value}, acc ->
          case Map.fetch(column_metadata, column) do
            {:ok, metadata} ->
              %{
                pretty_name: pretty_name,
                value_type: value_type
              } = metadata

              json_friendly_value = AstarteValue.to_json_friendly(column_value, value_type, [])

              Map.put(acc, pretty_name, json_friendly_value)

            :error ->
              acc
          end
        end)
      end

    {:ok, %InterfaceValues{data: values_list}}
  end

  def device_alias_to_device_id(realm_name, device_alias) do
    with {:ok, client} <- Database.connect(realm: realm_name) do
      Queries.device_alias_to_device_id(client, device_alias)
    else
      not_ok ->
        _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  defp fetch_biginteger_opts_or_default(opts) do
    allow_bigintegers = Map.get(opts, :allow_bigintegers)
    allow_safe_bigintegers = Map.get(opts, :allow_safe_bigintegers)

    cond do
      allow_bigintegers ->
        [allow_bigintegers: allow_bigintegers]

      allow_safe_bigintegers ->
        [allow_safe_bigintegers: allow_safe_bigintegers]

      # Default allow_bigintegers to true in order to not break the existing API
      true ->
        [allow_bigintegers: true]
    end
  end
end
