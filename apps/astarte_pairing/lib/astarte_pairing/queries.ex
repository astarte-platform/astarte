#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

  alias CQEx.Query
  alias CQEx.Result
  alias Astarte.Core.CQLUtils
  alias Astarte.Pairing.Config
  require Logger

  @protocol_revision 1

  def get_agent_public_key_pems(client) do
    get_jwt_public_key_pem = """
    SELECT blobAsVarchar(value)
    FROM kv_store
    WHERE group='auth' AND key='jwt_public_key_pem';
    """

    # TODO: add additional keys
    query =
      Query.new()
      |> Query.statement(get_jwt_public_key_pem)

    with {:ok, res} <- Query.call(client, query),
         ["system.blobasvarchar(value)": pem] <- Result.head(res) do
      {:ok, [pem]}
    else
      :empty_dataset ->
        {:error, :public_key_not_found}

      error ->
        Logger.warning("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  def register_device(client, device_id, extended_id, credentials_secret, opts \\ []) do
    statement = """
    SELECT first_credentials_request, first_registration
    FROM devices
    WHERE device_id=:device_id
    """

    device_exists_query =
      Query.new()
      |> Query.statement(statement)
      |> Query.put(:device_id, device_id)
      |> Query.consistency(:quorum)

    with {:ok, res} <- Query.call(client, device_exists_query) do
      case Result.head(res) do
        :empty_dataset ->
          registration_timestamp =
            DateTime.utc_now()
            |> DateTime.to_unix(:millisecond)

          Logger.info("register request for new device: #{inspect(extended_id)}")
          do_register_device(client, device_id, credentials_secret, registration_timestamp, opts)

        [first_credentials_request: nil, first_registration: registration_timestamp] ->
          Logger.info("register request for existing unconfirmed device: #{inspect(extended_id)}")

          do_register_unconfirmed_device(
            client,
            device_id,
            credentials_secret,
            registration_timestamp,
            opts
          )

        [first_credentials_request: _timestamp, first_registration: _registration_timestamp] ->
          Logger.warning(
            "register request for existing confirmed device: #{inspect(extended_id)}"
          )

          {:error, :already_registered}
      end
    else
      error ->
        Logger.warning("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  def unregister_device(client, device_id) do
    with :ok <- verify_already_registered_device(client, device_id),
         :ok <- do_unregister_device(client, device_id) do
      :ok
    else
      %{acc: _acc, msg: msg} ->
        Logger.warning("DB error: #{inspect(msg)}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warning("Unregister error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def check_already_registered_device(realm_name, device_id) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    Xandra.Cluster.run(:xandra, fn conn ->
      query = """
      SELECT device_id
      FROM #{keyspace_name}.devices
      WHERE device_id=:device_id
      """

      with {:ok, prepared} <- Xandra.prepare(conn, query),
           {:ok, page} <-
             Xandra.execute(conn, prepared, %{"device_id" => device_id},
               uuid_format: :binary,
               consistency: :quorum
             ) do
        case Enum.to_list(page) do
          [%{"device_id" => _device_id}] ->
            {:ok, true}

          [] ->
            {:ok, false}
        end
      end
    end)
  end

  defp verify_already_registered_device(client, device_id) do
    statement = """
    SELECT device_id
    FROM devices
    WHERE device_id=:device_id
    """

    query =
      Query.new()
      |> Query.statement(statement)
      |> Query.put(:device_id, device_id)
      |> Query.consistency(:quorum)

    with {:ok, res} <- Query.call(client, query) do
      case Result.head(res) do
        [device_id: _device_id] ->
          :ok

        :empty_dataset ->
          {:error, :device_not_registered}
      end
    end
  end

  defp do_unregister_device(client, device_id) do
    statement = """
    INSERT INTO devices
    (device_id, first_credentials_request, credentials_secret)
    VALUES (:device_id, :first_credentials_request, :credentials_secret)
    """

    query =
      Query.new()
      |> Query.statement(statement)
      |> Query.put(:device_id, device_id)
      |> Query.put(:first_credentials_request, nil)
      |> Query.put(:credentials_secret, nil)
      |> Query.consistency(:quorum)

    with {:ok, _res} <- Query.call(client, query) do
      :ok
    end
  end

  def select_device_for_credentials_request(client, device_id) do
    statement = """
    SELECT first_credentials_request, cert_aki, cert_serial, inhibit_credentials_request, credentials_secret
    FROM devices
    WHERE device_id=:device_id
    """

    do_select_device(client, device_id, statement)
  end

  def select_device_for_info(client, device_id) do
    statement = """
    SELECT credentials_secret, inhibit_credentials_request, first_credentials_request
    FROM devices
    WHERE device_id=:device_id
    """

    do_select_device(client, device_id, statement)
  end

  def select_device_for_verify_credentials(client, device_id) do
    statement = """
    SELECT credentials_secret
    FROM devices
    WHERE device_id=:device_id
    """

    do_select_device(client, device_id, statement)
  end

  def update_device_after_credentials_request(client, device_id, cert_data, device_ip, nil) do
    first_credentials_request_timestamp =
      DateTime.utc_now()
      |> DateTime.to_unix(:millisecond)

    update_device_after_credentials_request(
      client,
      device_id,
      cert_data,
      device_ip,
      first_credentials_request_timestamp
    )
  end

  def update_device_after_credentials_request(
        client,
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

    query =
      Query.new()
      |> Query.statement(statement)
      |> Query.put(:device_id, device_id)
      |> Query.put(:cert_aki, aki)
      |> Query.put(:cert_serial, serial)
      |> Query.put(:last_credentials_request_ip, device_ip)
      |> Query.put(:first_credentials_request, first_credentials_request_timestamp)
      |> Query.put(:protocol_revision, @protocol_revision)
      |> Query.consistency(:quorum)

    case Query.call(client, query) do
      {:ok, _res} ->
        :ok

      error ->
        Logger.warning("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  def fetch_device_registration_limit(realm_name) do
    Xandra.Cluster.run(:xandra, &do_fetch_device_registration_limit(&1, realm_name))
  end

  def fetch_registered_devices_count(realm_name) do
    Xandra.Cluster.run(:xandra, &do_fetch_registered_devices_count(&1, realm_name))
  end

  defp do_select_device(client, device_id, select_statement) do
    device_query =
      Query.new()
      |> Query.statement(select_statement)
      |> Query.put(:device_id, device_id)
      |> Query.consistency(:quorum)

    with {:ok, res} <- Query.call(client, device_query),
         device_row when is_list(device_row) <- Result.head(res) do
      {:ok, device_row}
    else
      :empty_dataset ->
        {:error, :device_not_found}

      error ->
        Logger.warning("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  defp do_register_device(client, device_id, credentials_secret, registration_timestamp, opts) do
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

    query =
      Query.new()
      |> Query.statement(statement)
      |> Query.put(:device_id, device_id)
      |> Query.put(:first_registration, registration_timestamp)
      |> Query.put(:credentials_secret, credentials_secret)
      |> Query.put(:inhibit_credentials_request, false)
      |> Query.put(:protocol_revision, 0)
      |> Query.put(:total_received_bytes, 0)
      |> Query.put(:total_received_msgs, 0)
      |> Query.put(:introspection, introspection)
      |> Query.put(:introspection_minor, introspection_minor)
      |> Query.consistency(:quorum)

    case Query.call(client, query) do
      {:ok, _res} ->
        :ok

      error ->
        Logger.warning("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  defp do_register_unconfirmed_device(
         client,
         device_id,
         credentials_secret,
         registration_timestamp,
         opts
       ) do
    statement = """
    UPDATE devices
    SET
      first_registration = :first_registration,
      credentials_secret = :credentials_secret,
      inhibit_credentials_request = :inhibit_credentials_request,
      protocol_revision = :protocol_revision,
      introspection = :introspection,
      introspection_minor = :introspection_minor

    WHERE device_id = :device_id
    """

    {introspection, introspection_minor} =
      opts
      |> Keyword.get(:initial_introspection, [])
      |> build_initial_introspection_maps()

    query =
      Query.new()
      |> Query.statement(statement)
      |> Query.put(:device_id, device_id)
      |> Query.put(:first_registration, registration_timestamp)
      |> Query.put(:credentials_secret, credentials_secret)
      |> Query.put(:inhibit_credentials_request, false)
      |> Query.put(:protocol_revision, 0)
      |> Query.put(:introspection, introspection)
      |> Query.put(:introspection_minor, introspection_minor)
      |> Query.consistency(:quorum)

    case Query.call(client, query) do
      {:ok, _res} ->
        :ok

      error ->
        Logger.warning("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  defp build_initial_introspection_maps(initial_introspection) do
    Enum.reduce(initial_introspection, {[], []}, fn introspection_entry, {majors, minors} ->
      %{
        interface_name: interface_name,
        major_version: major_version,
        minor_version: minor_version
      } = introspection_entry

      {[{interface_name, major_version} | majors], [{interface_name, minor_version} | minors]}
    end)
  end

  def check_astarte_health(consistency) do
    query = """
    SELECT COUNT(*)
    FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
    """

    with {:ok, %Xandra.Page{} = page} <-
           Xandra.Cluster.execute(:xandra, query, %{}, consistency: consistency),
         {:ok, _} <- Enum.fetch(page, 0) do
      :ok
    else
      :error ->
        _ =
          Logger.warning("Cannot retrieve count for astarte.realms table.",
            tag: "health_check_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warning("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp do_fetch_device_registration_limit(conn, realm_name) do
    query = """
    SELECT device_registration_limit
    FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
    WHERE realm_name = :realm_name
    """

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, page} <-
           Xandra.execute(conn, prepared, %{"realm_name" => realm_name}, consistency: :one) do
      case Enum.to_list(page) do
        [%{"device_registration_limit" => value}] ->
          {:ok, value}

        [] ->
          _ =
            Logger.warning(
              "cannot fetch device registration limit: realm #{realm_name} not found",
              tag: "realm_not_found"
            )

          {:error, :realm_not_found}
      end
    else
      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{Exception.message(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warning("Database error: #{Exception.message(err)}.",
            tag: "database_error"
          )

        {:error, :database_error}
    end
  end

  defp do_fetch_registered_devices_count(conn, realm_name) do
    # TODO move away from interpolation like this once NoaccOS' PR is merged
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    query = """
    SELECT COUNT(*)
    FROM #{keyspace_name}.devices
    """

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, page} <-
           Xandra.execute(conn, prepared, %{}, consistency: :one) do
      [%{"count" => value}] = Enum.to_list(page)
      {:ok, value}
    else
      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{Exception.message(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warning("Database error: #{Exception.message(err)}.",
            tag: "database_error"
          )

        {:error, :database_error}
    end
  end
end
