# Copyright 2017-2022 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.RealmManagement.RPC.HandlerTest do
  alias Astarte.RealmManagement.RPC.Handler

  alias Astarte.RPC.Protocol.RealmManagement.{
    GenericErrorReply,
    GetInterfacesListReply,
    GetInterfaceSourceReply,
    GetInterfaceVersionsListReply,
    GetInterfaceVersionsListReplyVersionTuple,
    Reply
  }

  use ExUnit.Case
  require Logger

  test "handle_rpc invalid messages and calls" do
    assert_raise FunctionClauseError, fn -> Handler.handle_rpc(nil) end
    assert_raise FunctionClauseError, fn -> assert Handler.handle_rpc([]) end
    assert Handler.handle_rpc("") == {:error, :unexpected_message}
  end

  test "encode error reply" do
    assert Handler.encode_reply(:test, {:error, :retry}) == {:error, :retry}

    assert Handler.encode_reply(:test, {:error, "some random string"}) ==
             {:error, "some random string"}

    expectedReply = %Reply{
      version: 0,
      error: true,
      reply:
        {:generic_error_reply,
         %GenericErrorReply{
           error_data: nil,
           error_name: "fake_error",
           user_readable_error_name: nil,
           user_readable_message: nil
         }}
    }

    {:ok, buf} = Handler.encode_reply(:test, {:error, :fake_error})
    assert Reply.decode(buf) == expectedReply
  end

  test "decode replies" do
    expectedReply = %Reply{
      version: 0,
      error: false,
      reply:
        {:get_interface_source_reply,
         %GetInterfaceSourceReply{
           source: "this_is_the_source"
         }}
    }

    {:ok, buf} = Handler.encode_reply(:get_interface_source, {:ok, "this_is_the_source"})
    assert Reply.decode(buf) == expectedReply

    expectedReply = %Reply{
      version: 0,
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
      Handler.encode_reply(
        :get_interface_versions_list,
        {:ok, [[major_version: 1, minor_version: 2], [major_version: 2, minor_version: 0]]}
      )

    assert Reply.decode(buf) == expectedReply

    expectedReply = %Reply{
      version: 0,
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

    {:ok, buf} = Handler.encode_reply(:get_interfaces_list, {:ok, ["interface.a", "interface.b"]})

    assert Reply.decode(buf) == expectedReply
  end
end
