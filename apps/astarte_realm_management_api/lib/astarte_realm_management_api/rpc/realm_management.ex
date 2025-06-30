#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.RPC.RealmManagement do
  alias Astarte.RPC.Protocol.RealmManagement.{
    Call,
    GenericErrorReply,
    GenericOkReply,
    GetInterfacesList,
    GetInterfacesListReply,
    Reply
  }

  alias Astarte.RealmManagement.API.Config

  require Logger

  @rpc_client Config.rpc_client!()
  @destination Astarte.RPC.Protocol.RealmManagement.amqp_queue()

  def get_interfaces_list(realm_name) do
    %GetInterfacesList{
      realm_name: realm_name
    }
    |> encode_call(:get_interfaces_list)
    |> @rpc_client.rpc_call(@destination)
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

  defp decode_reply({:error, reason}) do
    {:error, reason}
  end

  defp extract_reply({:generic_ok_reply, %GenericOkReply{async_operation: async}}) do
    if async do
      {:ok, :started}
    else
      :ok
    end
  end

  defp extract_reply({:generic_error_reply, %GenericErrorReply{error_name: name}}) do
    try do
      reason = String.to_existing_atom(name)
      {:error, reason}
    rescue
      ArgumentError ->
        _ = Logger.warning("Received unknown error: #{inspect(name)}.", tag: "amqp_generic_error")
        {:error, :unknown}
    end
  end

  defp extract_reply(
         {:get_interfaces_list_reply, %GetInterfacesListReply{interfaces_names: list}}
       ) do
    {:ok, list}
  end

  defp extract_reply({:error, :rpc_error}) do
    {:error, :rpc_error}
  end
end
