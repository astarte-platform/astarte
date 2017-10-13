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

defmodule Astarte.Pairing.Queries do
  @moduledoc """
  This module is responsible for the interaction with the database.
  """

  alias CQEx.Query
  alias CQEx.Result

  @insert_new_device """
  INSERT INTO devices
  (device_id, extended_id, inhibit_pairing, protocol_revision, total_received_bytes, total_received_msgs)
  VALUES (:device_id, :extended_id, :inhibit_pairing, :protocol_revision, :total_received_bytes, :total_received_msgs)
  """

  @select_device """
  SELECT device_id
  FROM devices
  WHERE device_id=:device_id
  """

  @select_device_for_pairing """
  SELECT extended_id, first_pairing
  FROM devices
  WHERE device_id=:device_id
  """

  @update_device_after_pairing """
  UPDATE devices
  SET cert_aki=:cert_aki, cert_serial=:cert_serial, last_pairing_ip=:last_pairing_ip, first_pairing=:first_pairing
  WHERE device_id=:device_id
  """

  def insert_device(client, device_uuid, extended_id) do
    #TODO: use IF NOT EXISTS as soon as Scylla supports it
    device_exists_query =
      Query.new()
      |> Query.statement(@select_device)
      |> Query.put(:device_id, device_uuid)

    case Query.call(client, device_exists_query) do
      {:ok, res} ->
        if Result.size(res) > 0 do
          {:error, :device_exists}
        else
          insert_not_existing_device(client, device_uuid, extended_id)
        end
      _error ->
        {:error, :db_error}
    end
  end

  def select_device_for_pairing(client, device_uuid) do
    device_query =
      Query.new()
      |> Query.statement(@select_device_for_pairing)
      |> Query.put(:device_id, device_uuid)

    case Query.call(client, device_query) do
      {:ok, res} ->
        if Enum.empty?(res) do
          {:error, :device_not_found}
        else
          {:ok, Result.head(res)}
        end

      _error ->
        {:error, :db_error}
    end
  end

  def update_device_after_pairing(client, device_uuid, cert_data, device_ip, :null) do
    first_pairing_timestamp =
      DateTime.utc_now()
      |> DateTime.to_unix(:milliseconds)

    update_device_after_pairing(client, device_uuid, cert_data, device_ip, first_pairing_timestamp)
  end
  def update_device_after_pairing(client, device_uuid, %{serial: serial, aki: aki} = _cert_data, device_ip, first_pairing_timestamp) do
    query =
      Query.new()
      |> Query.statement(@update_device_after_pairing)
      |> Query.put(:device_id, device_uuid)
      |> Query.put(:cert_aki, aki)
      |> Query.put(:cert_serial, serial)
      |> Query.put(:last_pairing_ip, device_ip)
      |> Query.put(:first_pairing, first_pairing_timestamp)

    case Query.call(client, query) do
      {:ok, _res} ->
        :ok

      _error ->
        {:error, :db_error}
    end
  end

  defp insert_not_existing_device(client, device_uuid, extended_id) do
    query =
      Query.new()
      |> Query.statement(@insert_new_device)
      |> Query.put(:device_id, device_uuid)
      |> Query.put(:extended_id, extended_id)
      |> Query.put(:inhibit_pairing, false)
      |> Query.put(:protocol_revision, 0)
      |> Query.put(:total_received_bytes, 0)
      |> Query.put(:total_received_msgs, 0)

    case Query.call(client, query) do
      {:ok, _res} ->
        :ok
      _error ->
        {:error, :db_error}
    end
  end
end
