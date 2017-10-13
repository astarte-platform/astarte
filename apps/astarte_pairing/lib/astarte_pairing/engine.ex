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

defmodule Astarte.Pairing.Engine do
  @moduledoc """
  This module performs the pairing operations requested via RPC.
  """

  alias Astarte.Pairing.APIKey
  alias Astarte.Pairing.Config
  alias Astarte.Pairing.Queries
  alias Astarte.Pairing.Utils
  alias CQEx.Client

  @version Mix.Project.config[:version]

  def get_info do
    %{version: @version,
      url: Config.broker_url!()}
  end

  def generate_api_key(realm, hardware_id) do
    with {:ok, device_uuid_bytes} <- Utils.extended_id_to_uuid(hardware_id) do

      device_uuid_string = :uuid.uuid_to_string(device_uuid_bytes)

      client =
        Config.cassandra_node()
        |> Client.new!(keyspace: realm)

      case Queries.insert_device(client, device_uuid_string, hardware_id) do
        :ok -> APIKey.generate(realm, device_uuid_bytes, "api_salt")
        error -> error
      end
    end
  end

  defp parse_ip(ip_string) do
    case to_charlist(ip_string) |> :inet.parse_address() do
      {:ok, ip_tuple} -> {:ok, ip_tuple}
      {:error, _} -> {:error, :invalid_ip}
    end
  end
end
