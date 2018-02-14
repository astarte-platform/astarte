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

defmodule Astarte.Pairing.API.RPC.AMQPClient do
  @moduledoc """
  This module sends RPC to the astarte_pairing backend
  """

  alias Astarte.Pairing.API.Config

  use Astarte.RPC.Protocol.Pairing
  use Astarte.RPC.AMQPClient

  def get_info do
    %GetInfo{}
    |> encode_call(:get_info)
    |> rpc_call()
    |> decode_reply()
    |> extract_reply()
  end

  def generate_api_key(realm, hw_id) do
    %GenerateAPIKey{realm: realm, hw_id: hw_id}
    |> encode_call(:generate_api_key)
    |> rpc_call()
    |> decode_reply()
    |> extract_reply()
  end

  def do_pairing(csr, api_key, device_ip) do
    %DoPairing{csr: csr, api_key: api_key, device_ip: device_ip}
    |> encode_call(:do_pairing)
    |> rpc_call()
    |> decode_reply()
    |> extract_reply()
  end

  def verify_certificate(certificate) do
    %VerifyCertificate{crt: certificate}
    |> encode_call(:verify_certificate)
    |> rpc_call()
    |> decode_reply()
    |> extract_reply()
  end

  defp encode_call(call, callname) do
    %Call{call: {callname, call}}
    |> Call.encode()
  end

  defp decode_reply({:ok, encoded_reply}) when is_binary(encoded_reply) do
    %Reply{reply: reply} = Reply.decode(encoded_reply)
    reply
  end

  defp extract_reply({:get_info_reply, %GetInfoReply{url: url, version: version}}) do
    {:ok, %{url: url, version: version}}
  end

  defp extract_reply({:generate_api_key_reply, %GenerateAPIKeyReply{api_key: api_key}}) do
    {:ok, api_key}
  end

  defp extract_reply({:do_pairing_reply, %DoPairingReply{client_crt: client_crt}}) do
    {:ok, client_crt}
  end

  defp extract_reply({:verify_certificate_reply, %VerifyCertificateReply{} = reply_struct}) do
    reply = %{
      valid: reply_struct.valid,
      timestamp: reply_struct.timestamp,
      until: reply_struct.until,
      cause: reply_struct.cause,
      details: reply_struct.details
    }

    {:ok, reply}
  end

  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    error_map = Map.from_struct(error_struct)

    {:error, error_map}
  end
end
