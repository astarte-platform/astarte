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

  @register_device """
  INSERT INTO devices
  (device_id, extended_id, credentials_secret, inhibit_credentials_request, protocol_revision, total_received_bytes, total_received_msgs)
  VALUES (:device_id, :extended_id, :credentials_secret, :inhibit_credentials_request, :protocol_revision, :total_received_bytes, :total_received_msgs)
  """

  @check_registered_device """
  SELECT first_credentials_request
  FROM devices
  WHERE device_id=:device_id
  """

  @select_device_for_credentials_request """
  SELECT extended_id, first_credentials_request, cert_aki, cert_serial, inhibit_credentials_request, credentials_secret
  FROM devices
  WHERE device_id=:device_id
  """

  @update_device_after_credentials_request """
  UPDATE devices
  SET cert_aki=:cert_aki, cert_serial=:cert_serial, last_credentials_request_ip=:last_credentials_request_ip,
    first_credentials_request=:first_credentials_request
  WHERE device_id=:device_id
  """

  def register_device(client, device_id, extended_id, credentials_secret) do
    device_exists_query =
      Query.new()
      |> Query.statement(@check_registered_device)
      |> Query.put(:device_id, device_id)

    with {:ok, res} <- Query.call(client, device_exists_query) do
      case Result.head(res) do
        :empty_dataset ->
          do_register_device(client, device_id, extended_id, credentials_secret)

        [first_credentials_request: nil] ->
          Logger.info("register request for existing unconfirmed device: #{inspect(extended_id)}")
          do_register_device(client, device_id, extended_id, credentials_secret)

        [first_credentials_request: _timestamp] ->
          Logger.warn("register request for existing confirmed device: #{inspect(extended_id)}")
          {:error, :already_registered}
      end
    else
      error ->
        Logger.warn("DB error: #{inspect(error)}")
        {:error, :db_error}
    end
  end

  def select_device_for_credentials_request(client, device_id) do
    device_query =
      Query.new()
      |> Query.statement(@select_device_for_credentials_request)
      |> Query.put(:device_id, device_id)

    with {:ok, res} <- Query.call(client, device_query),
         device_row when is_list(device_row) <- Result.head(res) do
      {:ok, device_row}
    else
      :empty_dataset ->
        {:error, :device_not_found}

      error ->
        Logger.warn("DB error: #{inspect(error)}")
        {:error, :db_error}
    end
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
    query =
      Query.new()
      |> Query.statement(@update_device_after_credentials_request)
      |> Query.put(:device_id, device_id)
      |> Query.put(:cert_aki, aki)
      |> Query.put(:cert_serial, serial)
      |> Query.put(:last_credentials_request_ip, device_ip)
      |> Query.put(:first_credentials_request, first_credentials_request_timestamp)

    case Query.call(client, query) do
      {:ok, _res} ->
        :ok

      error ->
        Logger.warn("DB error: #{inspect(error)}")
        {:error, :db_error}
    end
  end

  defp do_register_device(client, device_id, extended_id, credentials_secret) do
    query =
      Query.new()
      |> Query.statement(@register_device)
      |> Query.put(:device_id, device_id)
      |> Query.put(:extended_id, extended_id)
      |> Query.put(:credentials_secret, credentials_secret)
      |> Query.put(:inhibit_credentials_request, false)
      |> Query.put(:protocol_revision, 0)
      |> Query.put(:total_received_bytes, 0)
      |> Query.put(:total_received_msgs, 0)

    case Query.call(client, query) do
      {:ok, _res} ->
        :ok

      error ->
        Logger.warn("DB error: #{inspect(error)}")
        {:error, :db_error}
    end
  end
end
