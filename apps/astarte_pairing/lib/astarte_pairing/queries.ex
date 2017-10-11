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
