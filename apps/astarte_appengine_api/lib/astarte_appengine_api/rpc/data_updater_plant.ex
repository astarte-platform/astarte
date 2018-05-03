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

defmodule Astarte.AppEngine.API.RPC.DataUpdaterPlant do
  @moduledoc """
  This module sends RPC to DataUpdaterPlant
  """

  use Astarte.RPC.Protocol.DataUpdaterPlant

  alias Astarte.AppEngine.API.Config
  alias Astarte.AppEngine.API.RPC.VolatileTrigger

  @rpc_client Config.rpc_client()

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
    |> @rpc_client.rpc_call()
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
    |> @rpc_client.rpc_call()
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
