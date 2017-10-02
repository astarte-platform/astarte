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
  use Astarte.RPC.AMQPServer,
    queue: Application.fetch_env!(:astarte_pairing, :rpc_queue),
    amqp_options: Application.get_env(:astarte_pairing, :amqp_connection, [])
  use Astarte.RPC.Protocol.Pairing

  def process_rpc(_payload) do
    raise "TODO"
  end

  defp generic_error(error_name, user_readable_message \\ nil, user_readable_error_name \\ nil, error_data \\ nil) do
    %GenericErrorReply{error_name: to_string(error_name),
                       user_readable_message: user_readable_message,
                       user_readable_error_name: user_readable_error_name,
                       error_data: error_data}
    |> encode_reply(:generic_error_reply)
    |> ok_wrap
  end

  defp encode_reply(%GenericErrorReply{} = reply, _reply_type) do
    %Reply{reply: {:generic_error_reply, reply}, error: true}
    |> Reply.encode
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
