defmodule Astarte.Export.FetchData.Queries do
  require IEx
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Device

  require Logger

  def get_connection() do
    host = System.get_env("CASSANDRA_DB_HOST")
    port = System.get_env("CASSANDRA_DB_PORT")
    Logger.info("Connecting to #{inspect(host)}:#{inspect(port)} cassandra database.")

    with {:ok, xandra_conn} <- Xandra.start_link(nodes: ["#{host}:#{port}"], atom_keys: true) do
      Logger.info("Connected to database.")
      {:ok, xandra_conn}
    else
      {:error, reason} ->
        Logger.error("DB connection setup failed: #{inspect(reason)}",
          tag: "db_connection_failed"
        )
    end
  end

  def retrieve_interface_row(conn, realm, interface, major_version, options) do
    interface_statement = """
    SELECT name, major_version, minor_version, interface_id, type, ownership, aggregation,
      storage, storage_type, automaton_transitions, automaton_accepting_states
    FROM #{realm}.interfaces
    WHERE name=? AND major_version=?
    """

    params = [{"ascii", interface}, {"int", major_version}]

    options = options ++ [uuid_format: :binary, timestamp_format: :datetime]

    with {:ok, result} <- Xandra.execute(conn, interface_statement, params, options) do
      {:ok, result}
    else
      {:error, %Xandra.Error{message: message}} ->
        Logger.error("database error: #{inspect(message)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.error("database connection error:#{inspect(err)}.",
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}
    end
  end

  def fetch_interface_descriptor(conn, realm, interface, major_version, options) do
    with {:ok, interface_row} <-
           retrieve_interface_row(conn, realm, interface, major_version, options) do
      interface_row
      |> Enum.to_list()
      |> hd()
      |> InterfaceDescriptor.from_db_result()
    end
  end

  def stream_devices(conn, realm, options, device_options \\ []) do
    device_id = device_id_to_uuid(device_options[:device_id])

    {devices_statement, params} =
      case device_id do
        nil ->
          {
            """
            SELECT * from #{realm}.devices
            """,
            []
          }

        device_uuid ->
          {
            """
            SELECT * from #{realm}.devices WHERE device_id=?
            """,
            [{"uuid", device_id}]
          }
      end

    options = options ++ [uuid_format: :binary, timestamp_format: :datetime]

    with {:ok, result} <- Xandra.execute(conn, devices_statement, params, options) do
      {:ok, result}
    else
      {:error, %Xandra.Error{message: message}} ->
        Logger.error("database error: #{inspect(message)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.error("database connection error: #{inspect(err)}.",
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}
    end
  end

  def fetch_interface_mappings(conn, realm, interface_id, options) do
    mappings_statement = """
    SELECT endpoint, value_type, reliability, retention, database_retention_policy,
      database_retention_ttl, expiry, allow_unset, explicit_timestamp, endpoint_id, interface_id
    FROM #{realm}.endpoints
    WHERE interface_id=?
    """

    params = [{"uuid", interface_id}]

    options = options ++ [uuid_format: :binary, timestamp_format: :datetime]

    with {:ok, result} <- Xandra.execute(conn, mappings_statement, params, options) do
      mappings =
        result
        |> Enum.to_list()

      mappings_1 = Enum.map(mappings, &Mapping.from_db_result!/1)
      {:ok, mappings_1}
    else
      {:error, %Xandra.Error{message: message}} ->
        Logger.error("database error: #{inspect(message)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.error("database connection error:#{inspect(err)}.",
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}
    end
  end

  def retrieve_individual_properties(
        conn,
        realm,
        device_id,
        interface_id,
        endpoint_id,
        path,
        data_type,
        options
      ) do
    properties_statement = """
    SELECT  #{data_type}, reception_timestamp from #{realm}.individual_properties
      where device_id=? AND interface_id=? AND endpoint_id=? AND path=?
    """

    params = [{"uuid", device_id}, {"uuid", interface_id}, {"uuid", endpoint_id}, {"text", path}]

    options = options ++ [uuid_format: :binary, timestamp_format: :datetime]

    with {:ok, result} <- Xandra.execute(conn, properties_statement, params, options) do
      {:ok, result}
    else
      {:error, %Xandra.Error{message: message}} ->
        Logger.error("database error: #{inspect(message)}.",
          realm: realm,
          device_id: device_id,
          tag: "database_error"
        )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.error("database connection error:#{inspect(err)}.",
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}
    end
  end

  def retrieve_individual_datastreams(
        conn,
        realm,
        device_id,
        interface_id,
        endpoint_id,
        path,
        data_type,
        options
      ) do
    individual_datastream_statement = """
    SELECT #{data_type}, reception_timestamp FROM  #{realm}.individual_datastreams WHERE device_id=? AND
      interface_id=? AND endpoint_id=? AND path=?
    """

    params = [{"uuid", device_id}, {"uuid", interface_id}, {"uuid", endpoint_id}, {"text", path}]

    options = options ++ [uuid_format: :binary, timestamp_format: :datetime]

    with {:ok, result} <- Xandra.execute(conn, individual_datastream_statement, params, options) do
      {:ok, result}
    else
      {:error, %Xandra.Error{message: message}} ->
        Logger.error("database error: #{inspect(message)}.",
          realm: realm,
          device_id: device_id,
          tag: "database_error"
        )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.error("database connection error:#{inspect(err)}.",
          realm: realm,
          device_id: device_id,
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}
    end
  end

  def retrieve_object_datastream_value(conn, realm, storage, device_id, path, options) do
    object_datastream_statement = """
      SELECT * from #{realm}.#{storage} where device_id=? AND path=?
    """

    params = [{"uuid", device_id}, {"text", path}]

    options = options ++ [uuid_format: :binary, timestamp_format: :datetime]

    with {:ok, result} <-
           Xandra.execute(conn, object_datastream_statement, params, options) do
      {:ok, result}
    else
      {:error, %Xandra.Error{message: message}} ->
        Logger.error("database error: #{inspect(message)}.",
          realm: realm,
          device_id: device_id,
          tag: "database_error"
        )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.error("database connection error: #{inspect(err)}.",
          realm: realm,
          device_id: device_id,
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}
    end
  end

  def retrieve_all_endpoint_paths(conn, realm, interface_id, device_id, endpoint_id, aggregation) do
    {all_paths_statement, params} =
      case aggregation do
        :object ->
          {
            """
            SELECT path
            FROM #{realm}.individual_properties
            WHERE device_id=? AND interface_id=?
            """,
            [{"uuid", device_id}, {"uuid", interface_id}]
          }

        :individual ->
          {
            """
            SELECT path
            FROM #{realm}.individual_properties
            WHERE device_id=? AND interface_id=? AND endpoint_id=?
            """,
            [{"uuid", device_id}, {"uuid", interface_id}, {"uuid", endpoint_id}]
          }
      end

    with {:ok, result} <-
           Xandra.execute(conn, all_paths_statement, params) do
      rows = Enum.map(result, fn row -> row[:path] end)

      if rows == [] do
        Logger.info("No paths found for interface_id: #{inspect(interface_id)}",
          tag: "no_paths_found"
        )
      else
        {:ok, rows}
      end

      {:ok, rows}
    else
      {:error, %Xandra.Error{message: message}} ->
        Logger.error("database error: #{inspect(message)}.",
          realm: realm,
          device_id: device_id,
          tag: "database_error"
        )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.error("database connection error: #{inspect(err)}.",
          realm: realm,
          device_id: device_id,
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}
    end
  end

  defp device_id_to_uuid(device_id) when is_nil(device_id) do
    nil
  end

  defp device_id_to_uuid(device_id) do
    {:ok, device_uuid, _} = Device.decode_extended_device_id(device_id)
    device_uuid
  end
end
