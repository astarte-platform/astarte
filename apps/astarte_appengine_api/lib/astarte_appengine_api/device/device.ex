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

defmodule Astarte.AppEngine.API.Device do
  @moduledoc """
  The Device context.
  """
  alias Astarte.AppEngine.API.DataTransmitter
  alias Astarte.AppEngine.API.Device.AstarteValue
  alias Astarte.AppEngine.API.Device.DevicesListOptions
  alias Astarte.AppEngine.API.Device.MapTree
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.API.Device.InterfaceValuesOptions
  alias Astarte.AppEngine.API.Device.Queries
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Interface.Aggregation
  alias Astarte.Core.Interface.Type
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Device, as: DeviceQueries
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Ecto.Changeset
  require Logger

  def list_devices!(realm_name, params) do
    changeset = DevicesListOptions.changeset(%DevicesListOptions{}, params)

    with {:ok, options} <- Changeset.apply_action(changeset, :insert),
         {:ok, client} <- Database.connect(realm_name) do
      Queries.retrieve_devices_list(client, options.limit, options.details, options.from_token)
    end
  end

  @doc """
  Returns a DeviceStatus struct which represents device status.
  Device status returns information such as connected, last_connection and last_disconnection.
  """
  def get_device_status!(realm_name, encoded_device_id) do
    with {:ok, client} <- Database.connect(realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      Queries.retrieve_device_status(client, device_id)
    end
  end

  def merge_device_status!(realm_name, encoded_device_id, device_status_merge) do
    with {:ok, client} <- Database.connect(realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      Enum.find_value(Map.get(device_status_merge, "aliases", %{}), :ok, fn {alias_upd_key,
                                                                             alias_upd_value} ->
        result =
          if alias_upd_value do
            Queries.insert_alias(client, device_id, alias_upd_key, alias_upd_value)
          else
            Queries.delete_alias(client, device_id, alias_upd_key)
          end

        if match?({:error, _}, result) do
          result
        else
          nil
        end
      end)
    end
  end

  @doc """
  Returns the list of interfaces.
  """
  def list_interfaces(realm_name, encoded_device_id) do
    with {:ok, client} <- Database.connect(realm_name),
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
         {:ok, client} <- Database.connect(realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <- DeviceQueries.interface_version(client, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(client, interface, major_version) do
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
         {:ok, client} <- Database.connect(realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <- DeviceQueries.interface_version(client, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(client, interface, major_version),
         path <- "/" <> no_prefix_path,
         {:ok, endpoint_ids} <- get_endpoint_ids(interface_row, path, allow_guess: true) do
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

  def update_interface_values!(
        realm_name,
        encoded_device_id,
        interface,
        no_prefix_path,
        raw_value,
        _params
      ) do
    with {:ok, client} <- Database.connect(realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <- DeviceQueries.interface_version(client, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(client, interface, major_version),
         {:ok, interface_descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         {:ownership, :server} <- {:ownership, interface_descriptor.ownership},
         path <- "/" <> no_prefix_path,
         {:ok, [endpoint_id]} <- get_endpoint_ids(interface_row, path),
         mapping <-
           Queries.retrieve_mapping(client, interface_descriptor.interface_id, endpoint_id),
         {:ok, value} <- cast_value(mapping.value_type, raw_value),
         :ok <- validate_value_type(mapping.value_type, value) do
      timestamp_micro =
        DateTime.utc_now()
        |> DateTime.to_unix(:microseconds)

      Queries.insert_value_into_db(
        client,
        interface_descriptor.storage_type,
        device_id,
        interface_descriptor,
        endpoint_id,
        mapping,
        path,
        value,
        timestamp_micro
      )

      wrapped_value = wrap_to_bson_struct(mapping.value_type, value)

      case interface_descriptor.type do
        :properties ->
          DataTransmitter.set_property(realm_name, device_id, interface, path, wrapped_value)

        :datastream ->
          Queries.insert_path_into_db(
            client,
            device_id,
            interface_descriptor,
            endpoint_id,
            path,
            timestamp_micro,
            div(timestamp_micro, 1000)
          )

          DataTransmitter.push_datastream(realm_name, device_id, interface, path, wrapped_value)
      end

      {:ok,
       %InterfaceValues{
         data: value
       }}
    else
      {:ownership, :device} ->
        {:error, :cannot_write_to_device_owned}

      {:error, :endpoint_guess_not_allowed} ->
        {:error, :read_only_resource}

      {:error, :unexpected_value_type, expected: value_type} ->
        {:error, :unexpected_value_type, expected: value_type}

      {:error, reason} ->
        {:error, reason}
    end
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

  defp cast_value(:datetime, value) when is_binary(value) do
    with {:ok, datetime} <- DateTime.from_iso8601(value) do
      {:ok, datetime}
    else
      :error ->
        {:error, :unexpected_value_type, expected: :datetime}
    end
  end

  defp cast_value(:datetime, value) when is_integer(value) do
    with {:ok, datetime} <- DateTime.from_unix(value, :millisecond) do
      {:ok, datetime}
    else
      :error ->
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
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      with {:ok, casted_value} <- cast_value(:datetime, value) do
        {:cont, {:ok, [casted_value | acc]}}
      else
        {:error, :unexpected_value_type, expected: :datetime} ->
          {:halt, {:error, :unexpected_value_type, expected: :datetimearray}}
      end
    end)
  end

  defp cast_value(:binaryblobarray, values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      with {:ok, casted_value} <- cast_value(:binaryblob, value) do
        {:cont, {:ok, [casted_value | acc]}}
      else
        {:error, :unexpected_value_type, expected: :binaryblob} ->
          {:halt, {:error, :unexpected_value_type, expected: :binaryblobarray}}
      end
    end)
  end

  defp cast_value(_anytype, anyvalue) do
    {:ok, anyvalue}
  end

  defp wrap_to_bson_struct(:binaryblob, value) do
    %Bson.Bin{bin: value, subtype: Bson.Bin.subtyx(:binary)}
  end

  defp wrap_to_bson_struct(:binaryblobarray, values) do
    for value <- values do
      %Bson.Bin{bin: value, subtype: Bson.Bin.subtyx(:binary)}
    end
  end

  defp wrap_to_bson_struct(_anytype, value) do
    value
  end

  # TODO: we should probably allow delete for every path regardless of the interface type
  # just for maintenance reasons
  def delete_interface_values(realm_name, encoded_device_id, interface, no_prefix_path) do
    with {:ok, client} <- Database.connect(realm_name),
         {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, major_version} <- DeviceQueries.interface_version(client, device_id, interface),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(client, interface, major_version),
         {:ok, interface_descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         {:ownership, :server} <- {:ownership, interface_descriptor.ownership},
         path <- "/" <> no_prefix_path,
         {:ok, [endpoint_id]} <- get_endpoint_ids(interface_row, path) do
      mapping = Queries.retrieve_mapping(client, interface_descriptor.interface_id, endpoint_id)

      Queries.insert_value_into_db(
        client,
        interface_descriptor.storage_type,
        device_id,
        interface_descriptor,
        endpoint_id,
        mapping,
        path,
        nil,
        nil
      )

      case interface_descriptor.type do
        :properties ->
          DataTransmitter.unset_property(realm_name, device_id, interface, path)

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
    do_get_interface_values!(
      client,
      device_id,
      Aggregation.from_int(interface_row[:aggregation]),
      Type.from_int(interface_row[:type]),
      interface_row,
      nil,
      nil,
      "/",
      opts
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
    {status, result} =
      List.foldl(endpoint_ids, {:ok, %{}}, fn endpoint_id, {status, values} ->
        if status == :ok do
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

          if value != %{} do
            {:ok, Map.merge(values, value)}
          else
            {:error, :path_not_found}
          end
        else
          {status, values}
        end
      end)

    if status == :ok do
      individual_value = Map.get(result, "")

      data =
        if individual_value != nil do
          individual_value
        else
          MapTree.inflate_tree(result)
        end

      {:ok, %InterfaceValues{data: data}}
    else
      {:error, result}
    end
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
        opts
      )

    cond do
      path == "/" and interface_values == {:error, :path_not_found} ->
        {:ok, %InterfaceValues{data: []}}

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

  defp get_endpoint_ids(interface_metadata, path, opts \\ []) do
    automaton =
      {:erlang.binary_to_term(interface_metadata[:automaton_transitions]),
       :erlang.binary_to_term(interface_metadata[:automaton_accepting_states])}

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

          simplified_path = simplify_path(path, row_path)

          [
            {:value_timestamp, tstamp},
            {:reception_timestamp, reception},
            _,
            {_, v}
          ] =
            Queries.last_datastream_value!(
              client,
              device_id,
              interface_row,
              endpoint_row,
              endpoint_id,
              row_path,
              opts
            )

          nice_value =
            AstarteValue.to_json_friendly(
              v,
              ValueType.from_int(endpoint_row[:value_type]),
              allow_bigintegers: true
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
        )

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
                %InterfaceValuesOptions{limit: 1}
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
    {columns, column_atom_to_pretty_name, downsample_column_atom} =
      Enum.reduce(endpoint_rows, {"", %{}, nil}, fn endpoint,
                                                    {query_acc, atoms_map,
                                                     prev_downsample_column_atom} ->
        endpoint_name = endpoint[:endpoint]
        column_name = CQLUtils.endpoint_to_db_column_name(endpoint_name)

        next_query_acc = "#{query_acc} #{column_name}, "
        column_atom = String.to_atom(column_name)
        pretty_name = column_pretty_name(endpoint_name)
        next_atom_map = Map.put(atoms_map, column_atom, pretty_name)

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
    |> pack_result(:object, :datastream, column_atom_to_pretty_name, opts)
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
         _opts
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
              allow_bigintegers: true
            )

          Map.put(values_map, simplified_path, nice_value)
        else
          values_map
        end
      end)

    values
  end

  defp maybe_downsample_to(values, _count, _aggregation, %InterfaceValuesOptions{
         downsample_to: nil
       }) do
    values
  end

  defp maybe_downsample_to(values, nil, _aggregation, _opts) do
    # TODO: we can't downsample an object without a valid count, propagate an error changeset
    # when we start using changeset consistently here
    Logger.warn("No valid count in maybe_downsample_to")
    values
  end

  defp maybe_downsample_to(values, _count, :object, %InterfaceValuesOptions{downsample_key: nil}) do
    # TODO: we can't downsample an object without downsample_key, propagate an error changeset
    # when we start using changeset consistently here
    Logger.warn("No valid downsample_key found in maybe_downsample_to")
    values
  end

  defp maybe_downsample_to(values, count, :object, %InterfaceValuesOptions{
         downsample_to: downsampled_size,
         downsample_key: downsample_key
       })
       when downsampled_size > 2 do
    avg_bucket_size = max(1, (count - 2) / (downsampled_size - 2))

    sample_to_x_fun = fn sample -> Keyword.get(sample, :reception_timestamp) end
    sample_to_y_fun = fn sample -> Keyword.get(sample, downsample_key) end
    xy_to_sample_fun = fn x, y -> [{:reception_timestamp, x}, {downsample_key, y}] end

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
         column_atom_to_pretty_name,
         %{format: "table"} = opts
       ) do
    {_cols_count, columns, reverse_table_header} =
      Queries.first_result_row(values)
      |> List.foldl({1, %{"timestamp" => 0}, ["timestamp"]}, fn {column, _column_value},
                                                                {next_index, acc, list_acc} ->
        pretty_name = column_atom_to_pretty_name[column]

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
            value[:reception_timestamp],
            :datetime,
            keep_milliseconds: opts.keep_milliseconds
          )
        ]

        List.foldl(value, base_array_entry, fn {column, column_value}, acc ->
          pretty_name = column_atom_to_pretty_name[column]

          if pretty_name do
            [column_value | acc]
          else
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
         column_atom_to_pretty_name,
         %{format: "disjoint_tables"} = opts
       ) do
    reversed_columns_map =
      Enum.reduce(values, %{}, fn value, columns_acc ->
        List.foldl(value, columns_acc, fn {column, column_value}, acc ->
          pretty_name = column_atom_to_pretty_name[column]

          if pretty_name do
            column_list = [
              [
                column_value,
                AstarteValue.to_json_friendly(
                  value[:reception_timestamp],
                  :datetime,
                  keep_milliseconds: opts.keep_milliseconds
                )
              ]
              | Map.get(columns_acc, pretty_name, [])
            ]

            Map.put(acc, pretty_name, column_list)
          else
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
         column_atom_to_pretty_name,
         %{format: "structured"} = opts
       ) do
    values_list =
      for value <- values do
        base_array_entry = %{
          "timestamp" =>
            AstarteValue.to_json_friendly(
              value[:reception_timestamp],
              :datetime,
              keep_milliseconds: opts.keep_milliseconds
            )
        }

        List.foldl(value, base_array_entry, fn {column, column_value}, acc ->
          pretty_name = column_atom_to_pretty_name[column]

          if pretty_name do
            Map.put(acc, pretty_name, column_value)
          else
            acc
          end
        end)
      end

    {:ok, %InterfaceValues{data: values_list}}
  end

  def device_alias_to_device_id(realm_name, device_alias) do
    with {:ok, client} <- Database.connect(realm_name) do
      Queries.device_alias_to_device_id(client, device_alias)
    else
      not_ok ->
        Logger.warn("Device.device_alias_to_device_id: database error: #{inspect(not_ok)}")
        {:error, :database_error}
    end
  end
end
