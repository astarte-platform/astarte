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
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.Pairing.Queries do
  @moduledoc """
  This module is responsible for the interaction with the database.
  """

  alias CQEx.Query
  alias CQEx.Result

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
        Logger.warn("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  def register_device(client, device_id, extended_id, credentials_secret) do
    statement = """
    SELECT first_credentials_request
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
          do_register_device(client, device_id, credentials_secret)

        [first_credentials_request: nil] ->
          Logger.info("register request for existing unconfirmed device: #{inspect(extended_id)}")
          do_register_device(client, device_id, credentials_secret)

        [first_credentials_request: _timestamp] ->
          Logger.warn("register request for existing confirmed device: #{inspect(extended_id)}")
          {:error, :already_registered}
      end
    else
      error ->
        Logger.warn("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  def select_device_for_credentials_request(client, device_id) do
    statement = """
    SELECT extended_id, first_credentials_request, cert_aki, cert_serial, inhibit_credentials_request, credentials_secret
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
      |> DateTime.to_unix(:milliseconds)

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
        Logger.warn("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
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
        Logger.warn("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  defp do_register_device(client, device_id, credentials_secret) do
    statement = """
    INSERT INTO devices
    (device_id, credentials_secret, inhibit_credentials_request, protocol_revision, total_received_bytes, total_received_msgs)
    VALUES (:device_id, :credentials_secret, :inhibit_credentials_request, :protocol_revision, :total_received_bytes, :total_received_msgs)
    """

    query =
      Query.new()
      |> Query.statement(statement)
      |> Query.put(:device_id, device_id)
      |> Query.put(:credentials_secret, credentials_secret)
      |> Query.put(:inhibit_credentials_request, false)
      |> Query.put(:protocol_revision, 0)
      |> Query.put(:total_received_bytes, 0)
      |> Query.put(:total_received_msgs, 0)
      |> Query.consistency(:quorum)

    case Query.call(client, query) do
      {:ok, _res} ->
        :ok

      error ->
        Logger.warn("DB error: #{inspect(error)}")
        {:error, :database_error}
    end
  end
end
