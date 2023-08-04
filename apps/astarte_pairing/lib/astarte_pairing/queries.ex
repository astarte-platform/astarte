#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

defmodule Astarte.Pairing.Queries do
  @moduledoc """
  This module is responsible for the interaction with the database.
  """

  require Logger

  alias Astarte.Core.Realm

  @typedoc """
  A string representing the current context, to include in error messages.
  Not included if nil.
  Default: nil
  """
  @type custom_context() :: String.t() | nil

  @typedoc """
  The format of the result.
  Unless otherwise stated, all results are returned in an {:ok, value} tuple.
  - `:page`: default xandra return type
  - `:list`: a list
  - `{:first, default}`: only return the first element, `default` if empty
  - `:first`: shorthand for `{:first, nil}`
  - `{:first!, error}`: like `{:first, default}`, but returns `{:error, error}` if empty
  - `:first!`: shorthand for `{:first!, :not_found}`
  """
  @type custom_result() :: :page | :list | :first | :first! | {:first, any()} | {:first!, any()}

  @type custom_opt() :: {:context, custom_context()} | {:result, custom_result()}
  @type xandra_opt() :: {atom(), any()}

  @type query_opt() :: custom_opt() | xandra_opt()

  @protocol_revision 1
  @default_query_opts [uuid_format: :binary, timestamp_format: :integer]
  @default_custom_query_opts [result: :page, context: nil]

  @cluster Application.compile_env!(:astarte_pairing, :cluster_name)

  def get_agent_public_key_pems(realm_name) do
    statement = """
    SELECT blobAsVarchar(value)
    FROM kv_store
    WHERE group='auth' AND key='jwt_public_key_pem';
    """

    with {:ok, result} <-
           custom_query(statement, realm_name, %{},
             context: "agent public key fetch for realm #{realm_name}",
             result: {:first!, :public_key_not_found}
           ) do
      %{"system.blobasvarchar(value)" => pem} = result
      {:ok, [pem]}
    end
  end

  def register_device(realm_name, device_id, extended_id, credentials_secret, opts \\ []) do
    statement = """
    SELECT first_credentials_request, first_registration
    FROM devices
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    with {:ok, result} <-
           custom_query(statement, realm_name, params, consistency: :quorum, result: :first) do
      case result do
        nil ->
          registration_timestamp =
            DateTime.utc_now()
            |> DateTime.to_unix(:millisecond)

          Logger.info("register request for new device: #{inspect(extended_id)}")

          do_register_device(
            realm_name,
            device_id,
            credentials_secret,
            registration_timestamp,
            opts
          )

        %{"first_credentials_request" => nil, "first_registration" => registration_timestamp} ->
          Logger.info("register request for existing unconfirmed device: #{inspect(extended_id)}")

          do_register_device(
            realm_name,
            device_id,
            credentials_secret,
            registration_timestamp,
            opts
          )

        %{
          "first_credentials_request" => _timestamp,
          "first_registration" => _registration_timestamp
        } ->
          Logger.warn("register request for existing confirmed device: #{inspect(extended_id)}")
          {:error, :already_registered}
      end
    end
  end

  def unregister_device(realm_name, device_id) do
    with :ok <- check_already_registered_device(realm_name, device_id),
         :ok <- do_unregister_device(realm_name, device_id) do
      :ok
    end
  end

  defp check_already_registered_device(realm_name, device_id) do
    statement = """
    SELECT device_id
    FROM devices
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    with {:ok, _result} <-
           custom_query(statement, realm_name, params,
             consistency: :quorum,
             result: {:first!, :device_not_registered}
           ) do
      :ok
    end
  end

  defp do_unregister_device(realm_name, device_id) do
    statement = """
    INSERT INTO devices
    (device_id, first_credentials_request, credentials_secret)
    VALUES (:device_id, :first_credentials_request, :credentials_secret)
    """

    params = %{
      "device_id" => device_id,
      "first_credentials_request" => nil,
      "credentials_secret" => nil
    }

    case custom_query(statement, realm_name, params, consistency: :quorum) do
      {:ok, _result} ->
        :ok

      {:error, reason} ->
        _ = Logger.warn("Unregister error: #{reason}")
        {:error, reason}
    end
  end

  def select_device_for_credentials_request(realm_name, device_id) do
    statement = """
    SELECT first_credentials_request, cert_aki, cert_serial, inhibit_credentials_request, credentials_secret
    FROM devices
    WHERE device_id=:device_id
    """

    do_select_device(realm_name, device_id, statement)
  end

  def select_device_for_info(realm_name, device_id) do
    statement = """
    SELECT credentials_secret, inhibit_credentials_request, first_credentials_request
    FROM devices
    WHERE device_id=:device_id
    """

    do_select_device(realm_name, device_id, statement)
  end

  def select_device_for_verify_credentials(realm_name, device_id) do
    statement = """
    SELECT credentials_secret
    FROM devices
    WHERE device_id=:device_id
    """

    do_select_device(realm_name, device_id, statement)
  end

  def update_device_after_credentials_request(realm_name, device_id, cert_data, device_ip, nil) do
    first_credentials_request_timestamp =
      DateTime.utc_now()
      |> DateTime.to_unix(:millisecond)

    update_device_after_credentials_request(
      realm_name,
      device_id,
      cert_data,
      device_ip,
      first_credentials_request_timestamp
    )
  end

  def update_device_after_credentials_request(
        realm_name,
        device_id,
        %{serial: serial, aki: aki} = _cert_data,
        device_ip,
        first_credentials_request_timestamp
      ) do
    statement = """
    UPDATE devices
    SET cert_aki=:cert_aki, cert_serial=:cert_serial, last_credentials_request_ip=:last_credentials_request_ip,
    first_credentials_request=:first_credentials_request
    WHERE device_id=:device_id
    """

    params = %{
      "device_id" => device_id,
      "cert_aki" => aki,
      "cert_serial" => serial,
      "last_credentials_request_ip" => device_ip,
      "first_credentials_request" => first_credentials_request_timestamp,
      "protocol_revision" => @protocol_revision
    }

    with {:ok, _} <- custom_query(statement, realm_name, params, consistency: :quorum) do
      :ok
    end
  end

  defp do_select_device(realm_name, device_id, select_statement) do
    params = %{"device_id" => device_id}

    custom_query(select_statement, realm_name, params,
      consistency: :quorum,
      result: {:first!, :device_not_found}
    )
  end

  defp do_register_device(realm_name, device_id, credentials_secret, registration_timestamp, opts) do
    statement = """
    INSERT INTO devices
    (device_id, first_registration, credentials_secret, inhibit_credentials_request,
    protocol_revision, total_received_bytes, total_received_msgs, introspection,
    introspection_minor)
    VALUES
    (:device_id, :first_registration, :credentials_secret, :inhibit_credentials_request,
    :protocol_revision, :total_received_bytes, :total_received_msgs, :introspection,
    :introspection_minor)
    """

    {introspection, introspection_minor} =
      opts
      |> Keyword.get(:initial_introspection, [])
      |> build_initial_introspection_maps()

    params = %{
      "device_id" => device_id,
      "first_registration" => registration_timestamp,
      "credentials_secret" => credentials_secret,
      "inhibit_credentials_request" => false,
      "protocol_revision" => 0,
      "total_received_bytes" => 0,
      "total_received_msgs" => 0,
      "introspection" => introspection,
      "introspection_minor" => introspection_minor
    }

    with {:ok, _result} <- custom_query(statement, realm_name, params, consistency: :quorum) do
      :ok
    end
  end

  defp build_initial_introspection_maps(initial_introspection) do
    Enum.reduce(initial_introspection, {%{}, %{}}, fn introspection_entry, {majors, minors} ->
      %{
        interface_name: interface_name,
        major_version: major_version,
        minor_version: minor_version
      } = introspection_entry

      {Map.put(majors, interface_name, major_version),
       Map.put(minors, interface_name, minor_version)}
    end)
  end

  def check_astarte_health(consistency) do
    query = """
    SELECT COUNT(*)
    FROM astarte.realms
    """

    with {:ok, %Xandra.Page{} = page} <-
           Xandra.Cluster.execute(@cluster, query, %{}, consistency: consistency),
         {:ok, _} <- Enum.fetch(page, 0) do
      :ok
    else
      :error ->
        _ =
          Logger.warn("Cannot retrieve count for astarte.realms table.",
            tag: "health_check_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warn("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  @spec custom_query(Xandra.statement(), String.t() | nil, Xandra.values(), [query_opt()]) ::
          {:ok, term()} | {:error, term()}
  def custom_query(statement, realm \\ nil, params \\ %{}, opts \\ []) do
    {custom_opts, query_opts} = parse_opts(opts)

    Xandra.Cluster.run(@cluster, fn conn ->
      execute_query(conn, statement, realm, params, query_opts, custom_opts)
    end)
  end

  defp execute_query(conn, statement, realm, params, query_opts, custom_opts) do
    with {:ok, prepared} <- prepare_query(conn, statement, realm) do
      case Xandra.execute(conn, prepared, params, query_opts) do
        {:ok, page} ->
          cast_query_result(page, custom_opts)

        {:error, error} ->
          %{message: message, tag: tag} = database_error_message(error, custom_opts[:context])

          _ = Logger.warn(message, tag: tag)

          {:error, :database_error}
      end
    end
  end

  defp use_realm(_conn, nil = _realm), do: :ok

  defp use_realm(conn, realm) when is_binary(realm) do
    with true <- Realm.valid_name?(realm),
         {:ok, %Xandra.SetKeyspace{}} <- Xandra.execute(conn, "USE #{realm}") do
      :ok
    else
      _ -> {:error, :realm_not_found}
    end
  end

  defp prepare_query(conn, statement, realm) do
    with :ok <- use_realm(conn, realm) do
      case Xandra.prepare(conn, statement) do
        {:ok, page} ->
          {:ok, page}

        {:error, reason} ->
          _ = Logger.warn("Cannot prepare query: #{inspect(reason)}.", tag: "db_error")
          {:error, :database_error}
      end
    end
  end

  defp parse_opts(opts) do
    {custom_opts, query_opts} = Keyword.split(opts, Keyword.keys(@default_custom_query_opts))
    query_opts = Keyword.merge(@default_query_opts, query_opts)
    custom_opts = Keyword.validate!(custom_opts, @default_custom_query_opts)

    {custom_opts, query_opts}
  end

  defp cast_query_result(page, opts) do
    result_with_defaults =
      case opts[:result] do
        :first -> {:first, nil}
        :first! -> {:first!, :not_found}
        x -> x
      end

    case result_with_defaults do
      :page ->
        {:ok, page}

      :list ->
        {:ok, Enum.to_list(page)}

      {:first, default} ->
        {:ok, Enum.at(page, 0, default)}

      {:first!, error} ->
        Enum.at(page, 0)
        |> case do
          nil -> {:error, error}
          first -> {:ok, first}
        end
    end
  end

  defp database_error_message(error, context) do
    {error_type, error_tag} =
      case error do
        %Xandra.Error{} -> {"Database error", "db_error"}
        %Xandra.ConnectionError{} -> {"Database connection error", "db_connection_error"}
      end

    context = if context == nil, do: "", else: " during #{context}"

    message = error_type <> context <> ": " <> Exception.message(error)

    %{message: message, tag: error_tag}
  end
end
