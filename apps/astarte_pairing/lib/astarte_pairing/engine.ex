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
  alias Astarte.Pairing.CertVerifier
  alias Astarte.Pairing.CFSSLPairing
  alias Astarte.Pairing.Config
  alias Astarte.Pairing.Queries
  alias Astarte.Pairing.Utils
  alias CQEx.Client

  @version Mix.Project.config[:version]

  def do_pairing(csr, api_key, device_ip) do
    with {:ok, %{realm: realm, device_uuid: device_uuid}} <- APIKey.verify(api_key, "api_salt"),
         {:ok, ip_tuple} <- parse_ip(device_ip),
         {:ok, client} <- Config.cassandra_node() |> Client.new(keyspace: realm),
         {:ok, device} <- Queries.select_device_for_pairing(client, device_uuid),
         _ <- CFSSLPairing.revoke(device[:cert_serial], device[:cert_aki]),
         {:ok, %{cert: cert, aki: _aki, serial: _serial} = cert_data} <- CFSSLPairing.pair(csr, realm, device[:extended_id]),
         :ok <- Queries.update_device_after_pairing(client, device_uuid, cert_data, ip_tuple, device[:first_pairing]) do

      {:ok, cert}
    end
  end

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

  def verify_certificate(pem_cert) do
    CertVerifier.verify(pem_cert, Config.ca_cert())
  end

  defp parse_ip(ip_string) do
    case to_charlist(ip_string) |> :inet.parse_address() do
      {:ok, ip_tuple} -> {:ok, ip_tuple}
      {:error, _} -> {:error, :invalid_ip}
    end
  end
end
