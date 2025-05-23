defmodule Astarte.Export.FetchData do
  alias Astarte.Core.Device
  alias Astarte.Core.CQLUtils
  alias Astarte.Export.FetchData.Queries

  @base_types %{
    binaryblobarray: :binaryblob,
    datetimearray: :datetime,
    stringarray: :string,
    integerarray: :integer,
    longintegerarray: :longinteger,
    doublearray: :double,
    booleanarray: :boolean
  }

  def db_connection_identifier() do
    with {:ok, conn_ref} <- Queries.get_connection() do
      {:ok, conn_ref}
    else
      _ -> {:error, :connection_setup_failed}
    end
  end

  def fetch_device_data(conn, realm, options, device_options \\ []) do
    case Queries.stream_devices(conn, realm, options, device_options) do
      {:ok, result} ->
        result_list = Enum.to_list(result)

        if result_list == [] do
          {:ok, :completed}
        else
          updated_options = Keyword.put(options, :paging_state, result.paging_state)
          {:more_data, result_list, updated_options}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def process_device_data(device_data) do
    device_id = Device.encode_device_id(device_data.device_id)

    revision = to_string(device_data.protocol_revision)

    pending_empty_cache =
      to_string(device_data.pending_empty_cache)
      |> String.downcase()

    secret_bcrypt_hash = device_data.credentials_secret

    first_registration =
      case device_data.first_registration do
        nil -> ""
        datetime -> DateTime.to_iso8601(datetime)
      end

    inhibit_request =
      case device_data.inhibit_credentials_request do
        nil -> ""
        value -> value |> to_string() |> String.downcase()
      end

    cert_serial =
      case device_data.cert_serial do
        nil -> ""
        serial -> serial
      end

    cert_aki =
      case device_data.cert_aki do
        nil -> ""
        serial -> serial
      end

    first_credentials_request =
      case device_data.first_credentials_request do
        nil -> ""
        datetime -> DateTime.to_iso8601(datetime)
      end

    last_credentials_request_ip =
      case device_data.last_credentials_request_ip do
        nil -> ""
        ip -> ip |> :inet_parse.ntoa() |> to_string()
      end

    total_received_msgs =
      case device_data.total_received_msgs do
        nil -> "0"
        msgs -> to_string(msgs)
      end

    total_received_bytes =
      case device_data.total_received_bytes do
        nil -> "0"
        bytes -> to_string(bytes)
      end

    last_connection =
      case device_data.last_connection do
        nil -> ""
        datetime -> DateTime.to_iso8601(datetime)
      end

    last_disconnection =
      case device_data.last_disconnection do
        nil -> ""
        datetime -> DateTime.to_iso8601(datetime)
      end

    last_seen_ip =
      case device_data.last_seen_ip do
        nil -> ""
        ip -> ip |> :inet_parse.ntoa() |> to_string()
      end

    device_attributes = [device_id: device_id]

    protocol_attributes = [revision: revision, pending_empty_cache: pending_empty_cache]

    registration_attributes = [
      secret_bcrypt_hash: secret_bcrypt_hash,
      first_registration: first_registration
    ]

    credentials_attributes = [
      inhibit_request: inhibit_request,
      cert_serial: cert_serial,
      cert_aki: cert_aki,
      first_credentials_request: first_credentials_request,
      last_credentials_request_ip: last_credentials_request_ip
    ]

    stats_attributes = [
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes,
      last_connection: last_connection,
      last_disconnection: last_disconnection,
      last_seen_ip: last_seen_ip
    ]

    %{
      device: device_attributes,
      protocol: protocol_attributes,
      registration: registration_attributes,
      credentials: credentials_attributes,
      stats: stats_attributes
    }
  end

  def get_interface_details(conn, realm, device_data) do
    device_id = device_data.device_id
    introspection = device_data.introspection

    introspection = if introspection == nil, do: [], else: introspection

    mapped_interfaces =
      Enum.reduce(introspection, [], fn {interface_name, major_version}, acc ->
        {:ok, interface_description} =
          Queries.fetch_interface_descriptor(conn, realm, interface_name, major_version, [])

        minor_version = interface_description.minor_version
        interface_id = interface_description.interface_id
        aggregation = interface_description.aggregation
        storage = interface_description.storage
        interface_type = interface_description.type
        {:ok, mappings} = Queries.fetch_interface_mappings(conn, realm, interface_id, [])
        mappings = Enum.sort_by(mappings, fn mapping -> mapping.endpoint end)

        mappings =
          Enum.map(mappings, fn mapping ->
            path =
              fetch_all_endpoint_paths(
                conn,
                realm,
                interface_id,
                device_id,
                mapping.endpoint_id,
                aggregation
              )

            Map.put(mapping, :path, path |> Enum.at(0) || mapping.endpoint)
          end)

        interface_attributes = [
          name: interface_name,
          major_version: to_string(major_version),
          minor_version: to_string(minor_version),
          active: "true"
        ]

        type =
          case interface_type do
            :datastream ->
              case aggregation do
                :individual -> :individual
                :object -> :object
              end

            :properties ->
              :properties
          end

        [
          %{
            attributes: interface_attributes,
            interface_id: interface_id,
            device_id: device_id,
            storage: storage,
            type: type,
            mappings: mappings
          }
          | acc
        ]
      end)

    {:ok, mapped_interfaces}
  end

  defp fetch_all_endpoint_paths(conn, realm, interface_id, device_id, endpoint_id, aggregation) do
    with {:ok, result} <-
           Queries.retrieve_all_endpoint_paths(
             conn,
             realm,
             interface_id,
             device_id,
             endpoint_id,
             aggregation
           ) do
      result
    end
  end

  def fetch_individual_datastreams(conn, realm, mapping, interface_info, options) do
    %{
      device_id: device_id,
      interface_id: interface_id
    } = interface_info

    endpoint_id = mapping.endpoint_id
    path = mapping.path
    data_type = mapping.value_type
    data_field = CQLUtils.type_to_db_column_name(data_type)

    with {:ok, result} <-
           Queries.retrieve_individual_datastreams(
             conn,
             realm,
             device_id,
             interface_id,
             endpoint_id,
             path,
             data_field,
             options
           ),
         [_value | _] = result_list <- Enum.to_list(result) do
      updated_options = Keyword.put(options, :paging_state, result.paging_state)

      values =
        Enum.map(result_list, fn map ->
          atom_data_field = String.to_atom(data_field)
          return_value = map[atom_data_field]
          value = from_native_type(return_value, data_type)

          reception_timestamp = DateTime.to_iso8601(map.reception_timestamp)

          %{value: value, attributes: [reception_timestamp: reception_timestamp]}
        end)

      {:more_data, values, updated_options}
    else
      [] -> {:ok, :completed}
    end
  end

  def fetch_object_datastreams(conn, realm, interface_info, options) do
    %{
      device_id: device_id,
      storage: storage,
      path: path,
      sub_path_info: sub_path_info
    } = interface_info

    with {:ok, result} <-
           Queries.retrieve_object_datastream_value(
             conn,
             realm,
             storage,
             device_id,
             path,
             options
           ) do
      updated_options = Keyword.put(options, :paging_state, result.paging_state)
      result_list = Enum.to_list(result)

      values =
        Enum.reduce(result_list, [], fn map, acc ->
          reception_timestamp = DateTime.to_iso8601(map.reception_timestamp)

          list = Map.to_list(map)

          value_list =
            List.foldl(list, [], fn {key, value}, acc1 ->
              with "v_" <> item <- to_string(key),
                   match_object when match_object != nil <-
                     Enum.find(sub_path_info, fn map1 -> map1[:suffix_path] == item end),
                   data_type = match_object[:data_type],
                   token = "/" <> match_object[:suffix_path],
                   value1 when value1 != "" <- from_native_type(value, data_type) do
                [%{attributes: [name: token], value: value1} | acc1]
              else
                _ -> acc1
              end
            end)

          acc ++ [%{attributes: [reception_timestamp: reception_timestamp], value: value_list}]
        end)

      {:more_data, values, updated_options}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_individual_properties(conn, realm, mapping, interface_info, options) do
    %{
      device_id: device_id,
      interface_id: interface_id
    } = interface_info

    path = mapping.path
    endpoint_id = mapping.endpoint_id
    data_type = mapping.value_type
    data_field = CQLUtils.type_to_db_column_name(data_type)

    with {:ok, result} <-
           Queries.retrieve_individual_properties(
             conn,
             realm,
             device_id,
             interface_id,
             endpoint_id,
             path,
             data_field,
             options
           ),
         [_value | _] = result_list <- Enum.to_list(result) do
      updated_options = Keyword.put(options, :paging_state, result.paging_state)

      values =
        Enum.map(result_list, fn map ->
          reception_timestamp = DateTime.to_iso8601(map.reception_timestamp)

          path = to_string(path)

          atom_data_field = String.to_atom(data_field)
          return_value = map[atom_data_field]
          value = from_native_type(return_value, data_type)

          %{attributes: [reception_timestamp: reception_timestamp, path: path], value: value}
        end)

      {:more_data, values, updated_options}
    else
      [] -> {:ok, :completed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp from_native_type(value, native_type) when is_list(value) do
    type = Map.get(@base_types, native_type, native_type)
    Enum.map(value, &from_native_type(&1, type))
  end

  defp from_native_type(value, :binaryblob), do: Base.encode64(value)
  defp from_native_type(value, :datetime), do: DateTime.to_iso8601(value)
  defp from_native_type(value, _any_type), do: to_string(value)
end
