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

defmodule Astarte.RealmManagement.RPC.AMQPServerTest do
  alias Astarte.RealmManagement.RPC.AMQPServer
  use Astarte.RPC.Protocol.RealmManagement
  use ExUnit.Case
  require Logger

  test "process_rpc invalid messages and calls" do
    assert_raise FunctionClauseError, fn -> AMQPServer.process_rpc(nil) end
    assert_raise FunctionClauseError, fn -> assert AMQPServer.process_rpc([]) end
    assert AMQPServer.process_rpc("") == {:error, :unexpected_message}
  end

  test "encode error reply" do
    assert AMQPServer.encode_reply(:test, {:error, :retry}) == {:error, :retry}

    assert AMQPServer.encode_reply(:test, {:error, "some random string"}) ==
             {:error, "some random string"}

    expectedReply = %Reply{
      error: true,
      reply:
        {:generic_error_reply,
         %GenericErrorReply{
           error_data: nil,
           error_name: "fake_error",
           user_readable_error_name: nil,
           user_readable_message: nil
         }},
      version: 1
    }

    {:ok, buf} = AMQPServer.encode_reply(:test, {:error, :fake_error})
    assert Reply.decode(buf) == expectedReply
  end

  test "decode replies" do
    expectedReply = %Reply{
      error: false,
      reply:
        {:get_interface_source_reply,
         %GetInterfaceSourceReply{
           source: "this_is_the_source"
         }}
    }

    {:ok, buf} = AMQPServer.encode_reply(:get_interface_source, {:ok, "this_is_the_source"})
    assert Reply.decode(buf) == expectedReply

    expectedReply = %Reply{
      error: false,
      reply:
        {:get_interface_versions_list_reply,
         %GetInterfaceVersionsListReply{
           versions: [
             %GetInterfaceVersionsListReplyVersionTuple{
               major_version: 1,
               minor_version: 2
             },
             %GetInterfaceVersionsListReplyVersionTuple{
               major_version: 2,
               minor_version: 0
             }
           ]
         }}
    }

    {:ok, buf} =
      AMQPServer.encode_reply(
        :get_interface_versions_list,
        {:ok, [[major_version: 1, minor_version: 2], [major_version: 2, minor_version: 0]]}
      )

    assert Reply.decode(buf) == expectedReply

    expectedReply = %Reply{
      error: false,
      reply:
        {:get_interfaces_list_reply,
         %GetInterfacesListReply{
           interfaces_names: [
             "interface.a",
             "interface.b"
           ]
         }}
    }

    {:ok, buf} =
      AMQPServer.encode_reply(:get_interfaces_list, {:ok, ["interface.a", "interface.b"]})

    assert Reply.decode(buf) == expectedReply
  end
end
