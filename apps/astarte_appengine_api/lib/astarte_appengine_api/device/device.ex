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
  alias Astarte.AppEngine.API.Device.Aliases
  alias Astarte.AppEngine.API.Device.Attributes
  alias Astarte.AppEngine.API.Device.AstarteValue
  alias Astarte.AppEngine.API.Device.DevicesListOptions
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.MapTree
  alias Astarte.AppEngine.API.Device.InterfaceValue
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.API.Device.InterfaceValuesOptions
  alias Astarte.AppEngine.API.Device.Queries
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.DataAccess.Mappings
  alias Astarte.DataAccess.Device, as: DeviceQueries
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Ecto.Changeset

  require Logger

  def list_devices!(realm_name, params) do
    changeset = DevicesListOptions.changeset(%DevicesListOptions{}, params)

    with {:ok, options} <- Changeset.apply_action(changeset, :insert) do
      devices_list =
        Queries.retrieve_devices_list(
          realm_name,
          options.limit,
          options.details,
          options.from_token
        )

      {:ok, devices_list}
    end
  end

  @doc """
  Returns a DeviceStatus struct which represents device status.
  Device status returns information such as connected, last_connection and last_disconnection.
  """
  def get_device_status!(realm_name, encoded_device_id) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      Queries.retrieve_device_status(realm_name, device_id)
    end
  end

  def merge_device_status(realm_name, encoded_device_id, device_status_merge) do
    aliases = device_status_merge["aliases"]
    attributes = device_status_merge["attributes"]

    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, device} <- Queries.retrieve_device_for_status(realm_name, device_id),
         {:ok, aliases} <- Aliases.validate(aliases, realm_name, device),
         {:ok, attributes} <- Attributes.validate(attributes) do
      do_merge_device_status(realm_name, device_status_merge, device, aliases, attributes)
    end
  end

  defp do_merge_device_status(realm_name, device_status_merge, device, aliases, attributes) do
    params =
      case Map.fetch(device_status_merge, "credentials_inhibited") do
        {:ok, credentials_inhibited} -> %{credentials_inhibited: credentials_inhibited}
        :error -> %{}
      end

    changeset =
      DeviceStatus.from_db_row(device)
      |> Changeset.cast(params, [:credentials_inhibited])
      |> Aliases.apply(aliases)
      |> Attributes.apply(attributes)

    case Changeset.apply_action(changeset, :update) do
      {:ok, status} ->
        %Aliases{to_delete: alias_tags_to_delete, to_update: aliases_to_update} = aliases

        merge_device_status_result =
          Queries.merge_device_status(
            realm_name,
            device,
            changeset.changes,
            alias_tags_to_delete,
            aliases_to_update
          )

        with :ok <- merge_device_status_result do
          deletion_in_progress? = Queries.deletion_in_progress?(realm_name, device.device_id)
          {:ok, %{status | deletion_in_progress: deletion_in_progress?}}
        end

      {:error, changeset} ->
        {:error, sanitize_error(changeset)}
    end
  end

  defp sanitize_error(changeset) do
    # if there is a custom error, return it: it was created by Aliases.apply or Attributes.apply
    Enum.find_value(changeset.errors, changeset, fn
      {:aliases, {"", [reason: reason]}} -> reason
      {:attributes, {"", [reason: reason]}} -> reason
      _ -> false
    end)
  end

  @doc """
  Returns the list of interfaces.
  """
  def list_interfaces(realm_name, encoded_device_id) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      Queries.retrieve_interfaces_list(realm_name, device_id)
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

  @doc false
  def update_individual_interface_values(
        realm_name,
        device_id,
        interface_descriptor,
        path,
        raw_value
      ) do
    with {:ok, [endpoint_id]} <- get_endpoint_ids(interface_descriptor.automaton, path),
         mapping =
           Queries.retrieve_mapping(realm_name, interface_descriptor.interface_id, endpoint_id),
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
      realm_max_ttl = Queries.fetch_datastream_maximum_storage_retention(realm_name)

      now = DateTime.utc_now()

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

      with :ok <-
             Queries.insert_value_into_db(
               realm_name,
               device_id,
               interface_descriptor,
               endpoint_id,
               mapping,
               path,
               value,
               now,
               opts
             ) do
        if interface_descriptor.type == :datastream do
          Queries.insert_path_into_db(
            realm_name,
            device_id,
            interface_descriptor,
            endpoint_id,
            path,
            now,
            now,
            opts
          )
        end

        {:ok,
         %InterfaceValues{
           data: raw_value
         }}
      end
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

  @doc false
  def update_object_interface_values(
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
      realm_max_ttl = Queries.fetch_datastream_maximum_storage_retention(realm_name)
      db_max_ttl = min(realm_max_ttl, object_retention(mappings))

      opts =
        case db_max_ttl do
          nil ->
            []

          _ ->
            [ttl: db_max_ttl]
        end

      with :ok <-
             Queries.insert_value_into_db(
               realm_name,
               device_id,
               interface_descriptor,
               nil,
               nil,
               path,
               value,
               now,
               opts
             ) do
        Queries.insert_path_into_db(
          realm_name,
          device_id,
          interface_descriptor,
          endpoint_id,
          path,
          now,
          now,
          opts
        )

        {:ok,
         %InterfaceValues{
           data: raw_value
         }}
      end
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

        {:error, reason} ->
          {:halt, {:error, reason}}

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
        Queries.retrieve_mapping(realm_name, interface_descriptor.interface_id, endpoint_id)

      with :ok <-
             Queries.insert_value_into_db(
               realm_name,
               device_id,
               interface_descriptor,
               endpoint_id,
               mapping,
               path,
               nil,
               nil,
               []
             ) do
        case interface_descriptor.type do
          :properties ->
            unset_property(realm_name, device_id, interface, path)

          :datastream ->
            :ok
        end
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

    values_map =
      Enum.reduce(endpoint_rows, %{}, fn endpoint_row, values ->
        # TODO: we can do this by using just one query without any filter on the endpoint
        value =
          retrieve_endpoint_values(
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
    explicit_timestamp =
      Queries.interface_has_explicit_timestamp?(realm_name, interface_row.interface_id)

    do_get_interface_values!(
      realm_name,
      device_id,
      interface_row.aggregation,
      interface_row.type,
      interface_row,
      nil,
      "/",
      %{opts | explicit_timestamp: explicit_timestamp}
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
          Queries.value_type_query(realm_name, interface_row.interface_id, endpoint_id)

        value =
          retrieve_endpoint_values(
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
    endpoint_row = Queries.value_type_query(realm_name, interface_row.interface_id, endpoint_id)

    retrieve_endpoint_values(
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
    explicit_timestamp =
      Queries.interface_has_explicit_timestamp?(realm_name, interface_row.interface_id)

    endpoint_rows =
      Queries.retrieve_all_endpoints_for_interface!(realm_name, interface_row.interface_id)

    interface_values =
      retrieve_endpoint_values(
        realm_name,
        device_id,
        :object,
        :datastream,
        interface_row,
        nil,
        endpoint_rows,
        path,
        %{opts | explicit_timestamp: explicit_timestamp}
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

  defp retrieve_endpoint_values(
         realm_name,
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
    interface_id = interface_row.interface_id

    value_column =
      CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    values =
      Queries.retrieve_all_endpoint_paths!(realm_name, device_id, interface_id, endpoint_id)
      |> Enum.filter(fn endpoint -> endpoint[:path] |> String.starts_with?(path) end)
      |> Enum.reduce(%{}, fn row, values_map ->
        last_value =
          Queries.last_datastream_value!(
            realm_name,
            device_id,
            interface_row,
            endpoint_row,
            endpoint_id,
            row.path,
            opts
          )

        case last_value do
          {:ok, value} ->
            %{^value_column => v, value_timestamp: tstamp, reception_timestamp: reception} = value
            simplified_path = simplify_path(path, row.path)

            nice_value =
              AstarteValue.to_json_friendly(
                v,
                endpoint_row.value_type,
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

          {:error, _reason} ->
            %{}
        end
      end)

    values
  end

  defp retrieve_endpoint_values(
         realm_name,
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

    interface_id = interface_row.interface_id

    endpoint_id = CQLUtils.endpoint_id(interface_row.name, interface_row.major_version, "")

    {count, paths} =
      Queries.retrieve_all_endpoint_paths!(realm_name, device_id, interface_id, endpoint_id)
      |> Enum.reduce({0, []}, fn row, {count, all_paths} ->
        if String.starts_with?(row.path, path) do
          {count + 1, [row.path | all_paths]}
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
                 realm_name,
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
            Logger.warning("An error occurred while retrieving endpoint values: #{inspect(err)}",
              tag: "retrieve_endpoint_values_error"
            )

            err
        end

      count > 1 ->
        values_map =
          Enum.reduce(paths, %{}, fn a_path, values_map ->
            {:ok, %Astarte.AppEngine.API.Device.InterfaceValues{data: values}} =
              retrieve_endpoint_values(
                realm_name,
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
         realm_name,
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
    # https://github.com/elixir-ecto/ecto/pull/4384
    endpoints =
      endpoint_rows
      |> Enum.map(
        &%{
          column: &1.endpoint |> CQLUtils.endpoint_to_db_column_name() |> String.to_atom(),
          pretty_name: &1.endpoint |> String.split("/") |> List.last(),
          value_type: &1.value_type
        }
      )

    metadata = fn endpoint -> Map.take(endpoint, [:pretty_name, :value_type]) end
    columns = endpoints |> Enum.map(& &1.column)
    endpoint_metadata = endpoints |> Map.new(&{&1.column, metadata.(&1)})

    # The old implementation used the latest element it found for the downsample column.
    # Could we just drop the reverse and consider the first instead?
    downsample_column =
      endpoints
      |> Enum.reverse()
      |> Enum.find_value(&(&1.pretty_name == opts.downsample_key && &1.column))

    {count, values} =
      Queries.retrieve_object_datastream_values(
        realm_name,
        device_id,
        interface_row,
        endpoint_rows,
        path,
        columns,
        opts
      )

    values
    |> maybe_downsample_to(count, :object, nil, %InterfaceValuesOptions{
      opts
      | downsample_key: downsample_column
    })
    |> pack_result(:object, :datastream, endpoint_metadata, opts)
  end

  defp retrieve_endpoint_values(
         realm_name,
         device_id,
         :individual,
         :datastream,
         interface_row,
         endpoint_id,
         endpoint_row,
         path,
         opts
       ) do
    {count, values} =
      Queries.retrieve_datastream_values(
        realm_name,
        device_id,
        interface_row,
        endpoint_row,
        endpoint_id,
        path,
        opts
      )

    value_column =
      CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    values
    |> maybe_downsample_to(count, :individual, value_column, opts)
    |> pack_result(:individual, :datastream, endpoint_row, path, opts)
  end

  defp retrieve_endpoint_values(
         realm_name,
         device_id,
         :individual,
         :properties,
         interface_row,
         endpoint_id,
         endpoint_row,
         path,
         opts
       ) do
    value_column =
      CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    values =
      Queries.all_properties_for_endpoint!(
        realm_name,
        device_id,
        interface_row,
        endpoint_row,
        endpoint_id
      )
      |> Enum.filter(&String.starts_with?(&1.path, path))
      |> Enum.reduce(%{}, fn row, values_map ->
        %{^value_column => value, path: row_path} = row

        simplified_path = simplify_path(path, row_path)

        nice_value =
          AstarteValue.to_json_friendly(
            value,
            endpoint_row.value_type,
            fetch_biginteger_opts_or_default(opts)
          )

        Map.put(values_map, simplified_path, nice_value)
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

  defp maybe_downsample_to(values, _count, _aggregation, _value_column, %InterfaceValuesOptions{
         downsample_to: nil
       }) do
    values
  end

  defp maybe_downsample_to(values, nil, _aggregation, _value_column, _opts) do
    # TODO: we can't downsample an object without a valid count, propagate an error changeset
    # when we start using changeset consistently here
    _ = Logger.warning("No valid count in maybe_downsample_to.", tag: "downsample_invalid_count")
    values
  end

  defp maybe_downsample_to(values, _count, :object, _value_column, %InterfaceValuesOptions{
         downsample_key: nil
       }) do
    # TODO: we can't downsample an object without downsample_key, propagate an error changeset
    # when we start using changeset consistently here
    _ =
      Logger.warning("No valid downsample_key found in maybe_downsample_to.",
        tag: "downsample_invalid_key"
      )

    values
  end

  defp maybe_downsample_to(values, count, :object, _value_column, %InterfaceValuesOptions{
         downsample_to: downsampled_size,
         downsample_key: downsample_key,
         explicit_timestamp: explicit_timestamp
       })
       when downsampled_size > 2 do
    timestamp_column = timestamp_column(explicit_timestamp)
    avg_bucket_size = max(1, (count - 2) / (downsampled_size - 2))

    sample_to_x_fun = fn sample -> Map.fetch!(sample, timestamp_column) end
    sample_to_y_fun = fn sample -> Map.fetch!(sample, downsample_key) end
    xy_to_sample_fun = fn x, y -> %{timestamp_column => x, downsample_key => y} end

    values =
      Enum.map(values, fn value ->
        Map.update!(value, timestamp_column, &DateTime.to_unix(&1, :millisecond))
      end)

    ExLTTB.Stream.downsample(
      values,
      avg_bucket_size,
      sample_to_x_fun: sample_to_x_fun,
      sample_to_y_fun: sample_to_y_fun,
      xy_to_sample_fun: xy_to_sample_fun
    )
    |> Enum.to_list()
  end

  defp maybe_downsample_to(values, count, :individual, value_column, %InterfaceValuesOptions{
         downsample_to: downsampled_size
       })
       when downsampled_size > 2 do
    avg_bucket_size = max(1, (count - 2) / (downsampled_size - 2))

    sample_to_x_fun = fn sample -> sample.value_timestamp end
    sample_to_y_fun = fn sample -> Map.fetch!(sample, value_column) end

    xy_to_sample_fun = fn x, y -> %{value_column => y, value_timestamp: x} end

    values =
      Enum.map(values, fn value ->
        Map.update!(value, :value_timestamp, &DateTime.to_unix(&1, :millisecond))
      end)

    ExLTTB.Stream.downsample(
      values,
      avg_bucket_size,
      sample_to_x_fun: sample_to_x_fun,
      sample_to_y_fun: sample_to_y_fun,
      xy_to_sample_fun: xy_to_sample_fun
    )
  end

  defp pack_result([] = _values, :individual, :datastream, _endpoint_row, _path, _opts),
    do: {:error, :path_not_found}

  defp pack_result(
         values,
         :individual,
         :datastream,
         endpoint_row,
         _path,
         %{format: "structured"} = opts
       ) do
    value_key = CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    values_array =
      for value <- values do
        %{^value_key => v, value_timestamp: tstamp} = value

        %{
          "timestamp" =>
            AstarteValue.to_json_friendly(
              tstamp,
              :datetime,
              keep_milliseconds: opts.keep_milliseconds
            ),
          "value" => AstarteValue.to_json_friendly(v, endpoint_row.value_type, [])
        }
      end

    {:ok,
     %InterfaceValues{
       data: values_array
     }}
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

    value_key = CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    values_array =
      for value <- values do
        %{^value_key => v, value_timestamp: tstamp} = value

        [
          AstarteValue.to_json_friendly(tstamp, :datetime, []),
          AstarteValue.to_json_friendly(v, endpoint_row.value_type,
            keep_milliseconds: opts.keep_milliseconds
          )
        ]
      end

    {:ok,
     %InterfaceValues{
       metadata: %{
         "columns" => %{"timestamp" => 0, value_name => 1},
         "table_header" => ["timestamp", value_name]
       },
       data: values_array
     }}
  end

  defp pack_result(
         values,
         :individual,
         :datastream,
         endpoint_row,
         _path,
         %{format: "disjoint_tables"} = opts
       ) do
    value_key = CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    values_array =
      for value <- values do
        %{^value_key => v, value_timestamp: tstamp} = value

        [
          AstarteValue.to_json_friendly(v, endpoint_row.value_type, []),
          AstarteValue.to_json_friendly(
            tstamp,
            :datetime,
            keep_milliseconds: opts.keep_milliseconds
          )
        ]
      end

    {:ok,
     %InterfaceValues{
       data: %{"value" => values_array}
     }}
  end

  defp pack_result(
         values,
         :object,
         :datastream,
         column_metadata,
         %{format: "table"} = opts
       ) do
    data = object_datastream_pack(values, column_metadata, opts)

    table_header =
      case data do
        [] -> []
        [first | _] -> first |> Map.keys()
      end

    table_header_count = table_header |> Enum.count()
    columns = table_header |> Enum.zip(0..table_header_count) |> Map.new()

    values_array = data |> Enum.map(&Map.values/1)

    {:ok,
     %InterfaceValues{
       metadata: %{"columns" => columns, "table_header" => table_header},
       data: values_array
     }}
  end

  defp pack_result([] = _values, :object, :datastream, _column_metadata, %{
         format: "disjoint_tables"
       }),
       do: {:ok, %InterfaceValues{data: %{}}}

  defp pack_result(
         values,
         :object,
         :datastream,
         column_metadata,
         %{format: "disjoint_tables"} = opts
       ) do
    data = object_datastream_multilist(values, column_metadata, opts)
    {timestamps, data} = data |> Map.pop!("timestamp")

    columns =
      for {column, values} <- data, into: %{} do
        values_with_timestamp =
          Enum.zip_with(values, timestamps, fn value, timestamp -> [value, timestamp] end)

        {column, values_with_timestamp}
      end

    {:ok, %InterfaceValues{data: columns}}
  end

  defp pack_result(
         values,
         :object,
         :datastream,
         column_metadata,
         %{format: "structured"} = opts
       ) do
    data = object_datastream_pack(values, column_metadata, opts)
    {:ok, %InterfaceValues{data: data}}
  end

  defp object_datastream_multilist(values, column_metadata, opts) do
    timestamp_column = timestamp_column(opts.explicit_timestamp)
    keep_milliseconds? = opts.keep_milliseconds

    headers = values |> hd() |> Map.keys()
    headers_without_timestamp = headers |> List.delete(timestamp_column)

    timestamp_data =
      for value <- values do
        value
        |> Map.get(timestamp_column)
        |> AstarteValue.to_json_friendly(:datetime, keep_milliseconds: keep_milliseconds?)
      end

    for header <- headers_without_timestamp, into: %{"timestamp" => timestamp_data} do
      %{pretty_name: name, value_type: type} = column_metadata |> Map.fetch!(header)

      values =
        for value <- values do
          value
          |> Map.fetch!(header)
          |> AstarteValue.to_json_friendly(type, [])
        end

      {name, values}
    end
  end

  defp object_datastream_pack(values, column_metadata, opts) do
    timestamp_column = timestamp_column(opts.explicit_timestamp)
    keep_milliseconds? = opts.keep_milliseconds

    for value <- values do
      timestamp_value =
        value
        |> Map.get(timestamp_column)
        |> AstarteValue.to_json_friendly(:datetime, keep_milliseconds: keep_milliseconds?)

      value
      |> Map.delete(timestamp_column)
      |> Map.take(column_metadata |> Map.keys())
      |> Map.new(fn {column, value} ->
        %{pretty_name: name, value_type: type} = column_metadata |> Map.fetch!(column)
        value = AstarteValue.to_json_friendly(value, type, [])

        {name, value}
      end)
      |> Map.put("timestamp", timestamp_value)
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

  defp timestamp_column(explicit_timestamp?) do
    case explicit_timestamp? do
      false -> :reception_timestamp
      true -> :value_timestamp
    end
  end

  def device_alias_to_device_id(realm_name, device_alias) do
    Queries.device_alias_to_device_id(realm_name, device_alias)
  end
end
