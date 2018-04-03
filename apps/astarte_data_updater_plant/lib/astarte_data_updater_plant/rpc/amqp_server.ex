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

defmodule Astarte.DataUpdaterPlant.RPC.AMQPServer do
  @moduledoc false

  alias Astarte.DataUpdaterPlant.DataUpdater

  use Astarte.RPC.AMQPServer
  use Astarte.RPC.Protocol.DataUpdaterPlant

  def process_rpc(payload) do
    with {:ok, call_tuple} <- extract_call_tuple(Call.decode(payload)) do
      call_rpc(call_tuple)
    end
  end

  defp extract_call_tuple(%Call{call: nil}) do
    Logger.warn("Received empty call")
    {:error, :empty_call}
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    {:ok, call_tuple}
  end

  defp call_rpc(
         {:install_volatile_trigger,
          %InstallVolatileTrigger{
            realm_name: realm_name,
            device_id: device_id,
            object_id: object_id,
            object_type: object_type,
            parent_id: parent_id,
            simple_trigger: simple_trigger,
            trigger_target: trigger_target
          }}
       ) do
    # TODO: use faster random generator
    trigger_id = :uuid.get_v4()

    DataUpdater.handle_install_volatile_trigger(
      realm_name,
      device_id,
      object_id,
      object_type,
      parent_id,
      trigger_id,
      simple_trigger,
      trigger_target
    )

    %InstallVolatileTriggerReply{
      trigger_id: trigger_id
    }
    |> encode_reply()
    |> ok_wrap()
  end

  defp call_rpc(
         {:delete_volatile_trigger,
          %DeleteVolatileTrigger{
            realm_name: realm_name,
            device_id: device_id,
            trigger_id: trigger_id
          }}
       ) do
    DataUpdater.handle_delete_volatile_trigger(
      realm_name,
      device_id,
      trigger_id
    )

    %GenericOkReply{}
    |> encode_reply()
    |> ok_wrap()
  end

  defp generic_error(
         error_name,
         user_readable_message \\ nil,
         user_readable_error_name \\ nil,
         error_data \\ nil
       ) do
    %GenericErrorReply{
      error_name: to_string(error_name),
      user_readable_message: user_readable_message,
      user_readable_error_name: user_readable_error_name,
      error_data: error_data
    }
    |> encode_reply(:generic_error_reply)
    |> ok_wrap
  end

  defp encode_reply(%GenericOkReply{} = reply) do
    %Reply{reply: {:generic_ok_reply, reply}, error: false}
    |> Reply.encode()
  end

  defp encode_reply(%GenericErrorReply{} = reply, _reply_type) do
    %Reply{reply: {:generic_error_reply, reply}, error: true}
    |> Reply.encode()
  end

  defp encode_reply(%InstallVolatileTriggerReply{} = reply) do
    %Reply{reply: {:install_volatile_trigger_reply, reply}, error: false}
    |> Reply.encode()
  end

  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}}
    |> Reply.encode()
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
