#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.AppEngine.API.RPC.VMQPlugin do
  @moduledoc """
  This module sends RPC to VMQPlugin
  """
  require Logger

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
      _ = Logger.debug("Going to publish value on MQTT.")

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

    _ = Logger.debug("Got reply from VWQ: #{inspect(reply)}.")

    reply
  end

  defp extract_reply({:generic_ok_reply, %GenericOkReply{}}) do
    _ = Logger.debug("Got ok reply from VMQ.")

    :ok
  end

  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    error_map = Map.from_struct(error_struct)

    _ = Logger.error("Error while publishing value on MQTT.", tag: "vmq_publish_error")

    {:error, error_map}
  end
end
