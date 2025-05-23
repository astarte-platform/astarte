#
# This file is part of Astarte.
#
# Copyright 2018 - 2023 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.RPC.VMQPlugin do
  @moduledoc """
  This module sends RPC to VMQPlugin
  """

  alias Astarte.RPC.Protocol.VMQ.Plugin, as: Protocol

  alias Astarte.RPC.Protocol.VMQ.Plugin.{
    Call,
    Delete,
    Disconnect,
    GenericErrorReply,
    GenericOkReply,
    Publish,
    PublishReply,
    Reply
  }

  alias Astarte.DataUpdaterPlant.Config

  @rpc_client Config.rpc_client!()
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

  def delete(realm_name, device_id) do
    %Delete{
      realm_name: realm_name,
      device_id: device_id
    }
    |> encode_call(:delete)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def disconnect(client_id, discard_state)
      when is_binary(client_id) and is_boolean(discard_state) do
    %Disconnect{
      client_id: client_id,
      discard_state: discard_state
    }
    |> encode_call(:disconnect)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
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

  defp decode_reply({:error, "exception"}) do
    {:error, :vmq_plugin_rpc_exception}
  end

  defp extract_reply({:generic_ok_reply, %GenericOkReply{}}) do
    :ok
  end

  defp extract_reply({:publish_reply, %PublishReply{} = reply}) do
    {:ok, %{local_matches: reply.local_matches, remote_matches: reply.remote_matches}}
  end

  defp extract_reply({:generic_error_reply, %GenericErrorReply{error_name: "not_found"}}) do
    {:error, :not_found}
  end

  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    error_map = Map.from_struct(error_struct)

    {:error, error_map}
  end

  defp extract_reply({:error, :vmq_plugin_rpc_exception} = error) do
    error
  end
end
