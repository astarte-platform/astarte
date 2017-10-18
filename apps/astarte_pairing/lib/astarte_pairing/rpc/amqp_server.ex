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

defmodule Astarte.Pairing.RPC.AMQPServer do
  @moduledoc false

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.Engine

  use Astarte.RPC.AMQPServer,
    queue: Config.rpc_queue!(),
    amqp_options: Config.amqp_options()
  use Astarte.RPC.Protocol.Pairing

  def process_rpc(payload) do
    with {:ok, call_tuple} <- extract_call_tuple(Call.decode(payload)) do
      call_rpc(call_tuple)
    end
  end

  defp extract_call_tuple(%Call{call: nil}) do
    Logger.warn "Received empty call"
    {:error, :empty_call}
  end
  defp extract_call_tuple(%Call{call: call_tuple}) do
    {:ok, call_tuple}
  end

  defp call_rpc({:do_pairing, %DoPairing{csr: csr, api_key: api_key, device_ip: device_ip}}) do
    case Engine.do_pairing(csr, api_key, device_ip) do
      {:ok, certificate} ->
        %DoPairingReply{client_crt: certificate}
        |> encode_reply(:do_pairing_reply)
        |> ok_wrap()

      {:error, reason} ->
        generic_error(reason)
    end
  end
  defp call_rpc({:get_info, %GetInfo{}}) do
    %{url: url, version: version} = Engine.get_info()
    %GetInfoReply{url: url,
                  version: version}
    |> encode_reply(:get_info_reply)
    |> ok_wrap
  end
  defp call_rpc({:generate_api_key, %GenerateAPIKey{realm: realm, hw_id: hw_id}}) do
    case Engine.generate_api_key(realm, hw_id) do
      {:ok, api_key} ->
        %GenerateAPIKeyReply{api_key: api_key}
        |> encode_reply(:generate_api_key_reply)
        |> ok_wrap()

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp generic_error(error_name, user_readable_message \\ nil, user_readable_error_name \\ nil, error_data \\ nil) do
    %GenericErrorReply{error_name: to_string(error_name),
                       user_readable_message: user_readable_message,
                       user_readable_error_name: user_readable_error_name,
                       error_data: error_data}
    |> encode_reply(:generic_error_reply)
    |> ok_wrap
  end

  defp reason_to_certificate_validation_error(:cert_expired), do: :EXPIRED
  defp reason_to_certificate_validation_error(:invalid_issuer), do: :INVALID_ISSUER
  defp reason_to_certificate_validation_error(:invalid_signature), do: :INVALID_SIGNATURE
  defp reason_to_certificate_validation_error(:name_not_permitted), do: :NAME_NOT_PERMITTED
  defp reason_to_certificate_validation_error(:missing_basic_constraint), do: :MISSING_BASIC_CONSTRAINT
  defp reason_to_certificate_validation_error(:invalid_key_usage), do: :INVALID_KEY_USAGE
  defp reason_to_certificate_validation_error(:revoked), do: :REVOKED
  defp reason_to_certificate_validation_error(_), do: :INVALID

  defp encode_reply(%GenericErrorReply{} = reply, _reply_type) do
    %Reply{reply: {:generic_error_reply, reply}, error: true}
    |> Reply.encode
  end
  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}}
    |> Reply.encode
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
