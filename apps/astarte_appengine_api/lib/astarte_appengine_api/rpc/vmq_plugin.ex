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
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.AppEngine.API.RPC.VMQPlugin do
  @moduledoc """
  This module sends RPC to VMQPlugin
  """

  alias Astarte.RPC.Protocol.VMQ.Plugin, as: Protocol

  alias Astarte.RPC.Protocol.VMQ.Plugin.{
    Call,
    GenericErrorReply,
    GenericOkReply,
    Publish,
    Reply
  }

  alias Astarte.AppEngine.API.Config

  @rpc_client Config.rpc_client()
  @destination Protocol.amqp_queue()

  def publish(topic, payload, qos)
      when is_binary(topic) and is_binary(payload) and is_integer(qos) and qos >= 0 and qos <= 2 do
    with {:ok, tokens} <- split_topic(topic) do
      %Publish{
        topic_tokens: tokens,
        payload: payload,
        qos: qos
      }
      |> encode_call(:publish)
      |> @rpc_client.rpc_call(@destination)
      |> decode_reply()
      |> extract_reply()
    end
  end

  defp split_topic(topic) do
    case String.split(topic, "/") do
      [] -> {:error, :empty_topic}
      tokens -> {:ok, tokens}
    end
  end

  defp encode_call(call, callname) do
    %Call{call: {callname, call}}
    |> Call.encode()
  end

  defp decode_reply({:ok, encoded_reply}) when is_binary(encoded_reply) do
    %Reply{reply: reply} = Reply.decode(encoded_reply)
    reply
  end

  defp extract_reply({:generic_ok_reply, %GenericOkReply{}}) do
    :ok
  end

  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    error_map = Map.from_struct(error_struct)

    {:error, error_map}
  end
end
