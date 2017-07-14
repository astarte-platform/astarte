defmodule Astarte.RealmManagement.RPC.AMQPServerTest do
  use ExUnit.Case
  require Logger

  test "process_rpc invalid messages and calls" do
    assert_raise FunctionClauseError, fn -> Astarte.RealmManagement.RPC.AMQPServer.process_rpc(nil) end
    assert_raise FunctionClauseError, fn -> assert Astarte.RealmManagement.RPC.AMQPServer.process_rpc([]) end
    assert Astarte.RealmManagement.RPC.AMQPServer.process_rpc("") == {:error, :unexpected_message}
  end

  test "encode error reply" do
    assert Astarte.RealmManagement.RPC.AMQPServer.encode_reply(:test, {:error, :retry}) == {:error, :retry}


    assert Astarte.RealmManagement.RPC.AMQPServer.encode_reply(:test, {:error, "some random string"}) == {:error, "some random string"}

    expectedReply = %Astarte.RPC.Protocol.RealmManagement.Reply {
      error: true,
      reply: {:generic_error_reply, %Astarte.RPC.Protocol.RealmManagement.GenericErrorReply {
        error_data: nil,
        error_name: "fake_error",
        user_readable_error_name: nil,
        user_readable_message: nil
      }
    }, version: nil}

    {:ok, buf} = Astarte.RealmManagement.RPC.AMQPServer.encode_reply(:test, {:error, :fake_error})
    assert Astarte.RPC.Protocol.RealmManagement.Reply.decode(buf) == expectedReply
  end

  test "decode replies" do
    expectedReply = %Astarte.RPC.Protocol.RealmManagement.Reply {
      error: false,
      reply: {:get_interface_source_reply, %Astarte.RPC.Protocol.RealmManagement.GetInterfaceSourceReply {
        source: "this_is_the_source"
      }}
    }
    {:ok, buf} = Astarte.RealmManagement.RPC.AMQPServer.encode_reply(:get_interface_source, {:ok, "this_is_the_source"})
    assert Astarte.RPC.Protocol.RealmManagement.Reply.decode(buf) == expectedReply

    expectedReply = %Astarte.RPC.Protocol.RealmManagement.Reply {
      error: false,
      reply: {:get_interface_versions_list_reply, %Astarte.RPC.Protocol.RealmManagement.GetInterfaceVersionsListReply {
        versions: [
          %Astarte.RPC.Protocol.RealmManagement.GetInterfaceVersionsListReplyVersionTuple {
            major_version: 1,
            minor_version: 2
          },
          %Astarte.RPC.Protocol.RealmManagement.GetInterfaceVersionsListReplyVersionTuple {
            major_version: 2,
            minor_version: 0
          }
        ]
      }}
    }

    {:ok, buf} = Astarte.RealmManagement.RPC.AMQPServer.encode_reply(:get_interface_versions_list, {:ok, [[major_version: 1, minor_version: 2], [major_version: 2, minor_version: 0]]})
    assert Astarte.RPC.Protocol.RealmManagement.Reply.decode(buf) == expectedReply
  end

end
