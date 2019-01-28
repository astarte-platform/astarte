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

defmodule Astarte.AppEngine.API.RPC.DataUpdaterPlant do
  @moduledoc """
  This module sends RPC to DataUpdaterPlant
  """

  alias Astarte.RPC.Protocol.DataUpdaterPlant, as: Protocol

  alias Astarte.RPC.Protocol.DataUpdaterPlant.{
    Call,
    DeleteVolatileTrigger,
    GenericErrorReply,
    GenericOkReply,
    InstallVolatileTrigger,
    Reply
  }

  alias Astarte.AppEngine.API.Config
  alias Astarte.AppEngine.API.RPC.DataUpdaterPlant.VolatileTrigger

  @rpc_client Config.rpc_client()
  @destination Protocol.amqp_queue()

  def install_volatile_trigger(realm_name, device_id, %VolatileTrigger{} = volatile_trigger) do
    %VolatileTrigger{
      object_id: object_id,
      object_type: object_type,
      serialized_simple_trigger: serialized_simple_trigger,
      parent_id: parent_id,
      simple_trigger_id: simple_trigger_id,
      serialized_trigger_target: serialized_trigger_target
    } = volatile_trigger

    %InstallVolatileTrigger{
      realm_name: realm_name,
      device_id: device_id,
      object_id: object_id,
      object_type: object_type,
      parent_id: parent_id,
      simple_trigger: serialized_simple_trigger,
      simple_trigger_id: simple_trigger_id,
      trigger_target: serialized_trigger_target
    }
    |> encode_call(:install_volatile_trigger)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def delete_volatile_trigger(realm_name, device_id, trigger_id) do
    %DeleteVolatileTrigger{
      realm_name: realm_name,
      device_id: device_id,
      trigger_id: trigger_id
    }
    |> encode_call(:delete_volatile_trigger)
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

  defp extract_reply({:generic_ok_reply, %GenericOkReply{}}) do
    :ok
  end

  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    error_map = Map.from_struct(error_struct)

    {:error, error_map}
  end
end
