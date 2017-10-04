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
  IF NOT EXISTS
  """

  def insert_device(client, device_uuid, extended_id) do
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
      {:ok, result} ->
        applied =
          result
          |> Result.head()
          |> Keyword.get(:'[applied]')

        if applied do
          :ok
        else
          {:error, :device_exists}
        end

      {:error, _} ->
        {:error, :db_error}
    end
  end
end
