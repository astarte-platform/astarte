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

defmodule Astarte.AppEngine.API.Device do
  @moduledoc """
  The Device context.
  """
  alias Astarte.AppEngine.API.DataTransmitter
  alias Astarte.AppEngine.API.Device.Data
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.DevicesListOptions
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.InterfaceValue
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.API.Device.InterfaceValuesOptions
  alias Astarte.AppEngine.API.Device.MapTree
  alias Astarte.AppEngine.API.Device.Queries
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Device, as: DeviceQueries
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataAccess.Mappings
  alias Astarte.DataAccess.Repo
  alias Ecto.Changeset

  require Logger

  import Ecto.Query

  def list_devices!(realm_name, params) do
    changeset = DevicesListOptions.changeset(%DevicesListOptions{}, params)

    with {:ok, opts} <- Changeset.apply_action(changeset, :insert) do
      with_details? = opts.details

      devices =
        Queries.retrieve_devices_list(
          realm_name,
          opts.limit,
          with_details?,
          opts.from_token
        )
        |> Repo.all()

      devices_info =
        if with_details? do
          devices |> Enum.map(fn device -> DeviceStatus.from_device(device, realm_name) end)
        else
          devices
          |> Enum.map(fn device ->
            Device.encode_device_id(device.device_id)
          end)
        end

      device_list =
        if Enum.count(devices) < opts.limit do
          %DevicesList{devices: devices_info}
        else
          token = devices |> List.last() |> Map.fetch!("token")
          %DevicesList{devices: devices_info, last_token: token}
        end

      {:ok, device_list}
    end
  end

  @doc """
  Returns a DeviceStatus struct which represents device status.
  Device status returns information such as connected, last_connection and last_disconnection.
  """
  def get_device_status!(realm_name, encoded_device_id) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      retrieve_device_status(realm_name, device_id)
    end
  end

  def merge_device_status(realm_name, encoded_device_id, device_status_merge) do
    with {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, device_status} <- retrieve_device_status(realm_name, device_id),
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
        Logger.warning("Attribute key cannot be an empty string.",
          tag: :invalid_attribute_empty_key
        )

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
        Logger.warning("Alias value cannot be an empty string.", tag: :invalid_alias_empty_value)
        {:halt, {:error, :invalid_alias}}

      {"", _alias_value}, _acc ->
        Logger.warning("Alias key cannot be an empty string.", tag: :invalid_alias_empty_key)
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
    device_introspection = Queries.retrieve_interfaces_list(realm_name)

    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, device} <- Repo.fetch(device_introspection, device_id, error: :device_not_found) do
      interface_names = device.introspection |> Map.keys()
      {:ok, interface_names}
    end
  end

  @doc """
  Gets all values set on a certain interface.
  This function handles all GET requests on /{realm_name}/devices/{device_id}/interfaces/{interface}
  """
  def get_interface_values!(realm_name, encoded_device_id, interface, params) do
    changeset = InterfaceValuesOptions.changeset(%InterfaceValuesOptions{}, params)

    with {:ok, options} <- Changeset.apply_action(changeset, :insert),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <-
           DeviceQueries.interface_version(realm_name, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(realm_name, interface, major_version) do
      do_get_interface_values!(
        realm_name,
        device_id,
        interface_row.aggregation,
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
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <-
           DeviceQueries.interface_version(realm_name, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(realm_name, interface, major_version),
         path <- "/" <> no_prefix_path,
         {:ok, interface_descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         {:ok, endpoint_ids} <-
           get_endpoint_ids(interface_descriptor.automaton, path, allow_guess: true) do
      do_get_interface_values!(
        realm_name,
        device_id,
        interface_row.aggregation,
        interface_row.type,
        interface_row,
        endpoint_ids,
        path,
        options
      )
    end
  end

  defp update_individual_interface_values(
         realm_name,
         device_id,
         interface_descriptor,
         path,
         raw_value
       ) do
    with {:ok, [endpoint_id]} <- get_endpoint_ids(interface_descriptor.automaton, path),
         mapping =
           Queries.retrieve_mapping(realm_name)
           |> Repo.get_by!(%{
             interface_id: interface_descriptor.interface_id,
             endpoint_id: endpoint_id
           }),
         {:ok, value} <- InterfaceValue.cast_value(mapping.value_type, raw_value),
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
           ) do
      realm_max_ttl = Queries.datastream_maximum_storage_retention(realm_name) |> Repo.one()
      now = DateTime.utc_now()

      db_max_ttl =
        if mapping.database_retention_policy == :use_ttl do
          min(realm_max_ttl, mapping.database_retention_ttl)
        else
          realm_max_ttl
        end

      opts = [ttl: db_max_ttl]

      Data.insert_value(
        realm_name,
        device_id,
        interface_descriptor,
        endpoint_id,
        mapping,
        path,
        value,
        now,
        opts
      )

      if interface_descriptor.type == :datastream do
        Data.insert_path(
          realm_name,
          device_id,
          interface_descriptor,
          endpoint_id,
          path,
          now,
          opts
        )
      end

      {:ok,
       %InterfaceValues{
         data: raw_value
       }}
    else
      {:error, :endpoint_guess_not_allowed} ->
        _ = Logger.warning("Incomplete path not allowed.", tag: "endpoint_guess_not_allowed")
        {:error, :read_only_resource}

      {:error, :unexpected_value_type, expected: value_type} ->
        _ = Logger.warning("Unexpected value type.", tag: "unexpected_value_type")
        {:error, :unexpected_value_type, expected: value_type}

      {:error, reason} ->
        _ = Logger.warning("Error while writing to interface.", tag: "write_to_device_error")
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
      Map.new(mappings, fn mapping ->
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
        Logger.warning(
          "Tried to publish on endpoint #{inspect(path)} for object aggregated " <>
            "interface #{inspect(interface_descriptor.name)}. You should publish on " <>
            "the common prefix",
          tag: "invalid_path"
        )

        {:error, :mapping_not_found}

      {:error, :not_found} ->
        Logger.warning(
          "Tried to publish on invalid path #{inspect(path)} for object aggregated " <>
            "interface #{inspect(interface_descriptor.name)}",
          tag: "invalid_path"
        )

        {:error, :mapping_not_found}

      {:error, :invalid_object_aggregation_path} ->
        Logger.warning(
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
         realm_name,
         device_id,
         interface_descriptor,
         path,
         raw_value
       ) do
    now = DateTime.utc_now()

    with {:ok, mappings} <-
           Mappings.fetch_interface_mappings(
             realm_name,
             interface_descriptor.interface_id
           ),
         {:ok, endpoint} <-
           resolve_object_aggregation_path(path, interface_descriptor, mappings),
         endpoint_id <- endpoint.endpoint_id,
         expected_types <- extract_expected_types(mappings),
         {:ok, value} <- InterfaceValue.cast_value(expected_types, raw_value),
         :ok <- validate_value_type(expected_types, value),
         wrapped_value = wrap_to_bson_struct(expected_types, value),
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
           ) do
      realm_max_ttl = Queries.datastream_maximum_storage_retention(realm_name) |> Repo.one()
      db_max_ttl = min(realm_max_ttl, object_retention(mappings))

      opts =
        case db_max_ttl do
          nil ->
            []

          _ ->
            [ttl: db_max_ttl]
        end

      Data.insert_value(
        realm_name,
        device_id,
        interface_descriptor,
        nil,
        nil,
        path,
        value,
        now,
        opts
      )

      Data.insert_path(
        realm_name,
        device_id,
        interface_descriptor,
        endpoint_id,
        path,
        now,
        opts
      )

      {:ok,
       %InterfaceValues{
         data: raw_value
       }}
    else
      {:error, :unexpected_value_type, expected: value_type} ->
        Logger.warning("Unexpected value type.", tag: "unexpected_value_type")
        {:error, :unexpected_value_type, expected: value_type}

      {:error, :invalid_object_aggregation_path} ->
        Logger.warning("Error while trying to publish on path for object aggregated interface.",
          tag: "invalid_object_aggregation_path"
        )

        {:error, :invalid_object_aggregation_path}

      {:error, :mapping_not_found} ->
        {:error, :mapping_not_found}

      {:error, :database_error} ->
        Logger.warning("Error while trying to retrieve ttl.", tag: "database_error")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warning(
          "Unhandled error while updating object interface values: #{inspect(reason)}."
        )

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
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <-
           DeviceQueries.interface_version(realm_name, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(realm_name, interface, major_version),
         {:ok, interface_descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         {:ownership, :server} <- {:ownership, interface_descriptor.ownership},
         path <- "/" <> no_prefix_path do
      if interface_descriptor.aggregation == :individual do
        update_individual_interface_values(
          realm_name,
          device_id,
          interface_descriptor,
          path,
          raw_value
        )
      else
        update_object_interface_values(
          realm_name,
          device_id,
          interface_descriptor,
          path,
          raw_value
        )
      end
    else
      {:ownership, :device} ->
        _ = Logger.warning("Invalid write (device owned).", tag: "cannot_write_to_device_owned")
        {:error, :cannot_write_to_device_owned}

      {:error, reason} ->
        _ = Logger.warning("Error while writing to interface.", tag: "write_to_device_error")
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
    Logger.warning(
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

  defp wrap_to_bson_struct(:binaryblob, value) do
    # 0 is generic binary subtype
    {0, value}
  end

  defp wrap_to_bson_struct(:binaryblobarray, values) do
    Enum.map(values, &wrap_to_bson_struct(:binaryblob, &1))
  end

  defp wrap_to_bson_struct(expected_types, values)
       when is_map(expected_types) and is_map(values) do
    Enum.map(values, fn {key, value} ->
      # We can be sure this exists since we validated it in validate_value_type
      type = Map.fetch!(expected_types, key)
      {key, wrap_to_bson_struct(type, value)}
    end)
    |> Enum.into(%{})
  end

  defp wrap_to_bson_struct(_anytype, value) do
    value
  end

  # TODO: we should probably allow delete for every path regardless of the interface type
  # just for maintenance reasons
  def delete_interface_values(realm_name, encoded_device_id, interface, no_prefix_path) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <-
           DeviceQueries.interface_version(realm_name, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(realm_name, interface, major_version),
         {:ok, interface_descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         {:ownership, :server} <- {:ownership, interface_descriptor.ownership},
         path <- "/" <> no_prefix_path,
         {:ok, [endpoint_id]} <- get_endpoint_ids(interface_descriptor.automaton, path) do
      mapping =
        Queries.retrieve_mapping(realm_name)
        |> Repo.get_by!(%{
          interface_id: interface_descriptor.interface_id,
          endpoint_id: endpoint_id
        })

      Data.insert_value(
        realm_name,
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

  defp do_get_interface_values!(realm_name, device_id, :individual, interface_row, opts) do
    endpoint_rows =
      Queries.retrieve_all_endpoint_ids_for_interface!(realm_name, interface_row.interface_id)
      |> Repo.all()

    values_map =
      Enum.reduce(endpoint_rows, %{}, fn endpoint_row, values ->
        # TODO: we can do this by using just one query without any filter on the endpoint
        value =
          Data.endpoint_values(
            realm_name,
            device_id,
            interface_row.aggregation,
            interface_row.type,
            interface_row,
            endpoint_row.endpoint_id,
            endpoint_row,
            "/",
            opts
          )

        Map.merge(values, value)
      end)

    {:ok, %InterfaceValues{data: MapTree.inflate_tree(values_map)}}
  end

  defp do_get_interface_values!(realm_name, device_id, :object, interface_row, opts) do
    # We need to know if mappings have explicit_timestamp set, so we retrieve it from the
    # first one.
    endpoint =
      Queries.retrieve_all_endpoint_ids_for_interface!(realm_name, interface_row.interface_id)
      |> limit(1)
      |> Repo.one!()

    mapping =
      Queries.retrieve_mapping(realm_name)
      |> Repo.get_by!(%{
        interface_id: interface_row.interface_id,
        endpoint_id: endpoint.endpoint_id
      })

    do_get_interface_values!(
      realm_name,
      device_id,
      interface_row.aggregation,
      interface_row.type,
      interface_row,
      nil,
      "/",
      %{opts | explicit_timestamp: mapping.explicit_timestamp}
    )
  end

  defp do_get_interface_values!(
         realm_name,
         device_id,
         :individual,
         :properties,
         interface_row,
         endpoint_ids,
         path,
         opts
       ) do
    result =
      List.foldl(endpoint_ids, %{}, fn endpoint_id, values ->
        endpoint_row =
          Queries.value_type_query(realm_name)
          |> Repo.get_by!(%{interface_id: interface_row.interface_id, endpoint_id: endpoint_id})

        value =
          Data.endpoint_values(
            realm_name,
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
         realm_name,
         device_id,
         :individual,
         :datastream,
         interface_row,
         endpoint_ids,
         path,
         opts
       ) do
    [endpoint_id] = endpoint_ids

    endpoint_row =
      Queries.value_type_query(realm_name)
      |> Repo.get_by!(%{interface_id: interface_row.interface_id, endpoint_id: endpoint_id})

    Data.endpoint_values(
      realm_name,
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
         realm_name,
         device_id,
         :object,
         :datastream,
         interface_row,
         _endpoint_ids,
         path,
         opts
       ) do
    # We need to know if mappings have explicit_timestamp set, so we retrieve it from the
    # first one.
    endpoint =
      Queries.retrieve_all_endpoint_ids_for_interface!(realm_name, interface_row.interface_id)
      |> limit(1)
      |> Repo.one!()

    mapping =
      Queries.retrieve_mapping(realm_name)
      |> Repo.get_by!(%{
        interface_id: interface_row.interface_id,
        endpoint_id: endpoint.endpoint_id
      })

    endpoint_rows =
      Queries.retrieve_all_endpoints_for_interface!(realm_name, interface_row.interface_id)
      |> Repo.all()

    interface_values =
      Data.endpoint_values(
        realm_name,
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

  defp retrieve_device_status(realm_name, device_id) do
    device_query = Queries.device_status(realm_name)

    with {:ok, device} <- Repo.fetch(device_query, device_id, error: :device_not_found) do
      {:ok, DeviceStatus.from_device(device, realm_name)}
    end
  end

  def device_alias_to_device_id(realm_name, device_alias) do
    with {:ok, client} <- Database.connect(realm: realm_name) do
      Queries.device_alias_to_device_id(client, device_alias)
    else
      not_ok ->
        _ = Logger.warning("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :database_error}
    end
  end
end
