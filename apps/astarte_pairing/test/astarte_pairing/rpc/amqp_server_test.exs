defmodule Astarte.Pairing.AMQPServerTest do
  use ExUnit.Case

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.RPC.AMQPServer

  use Astarte.RPC.Protocol.Pairing

  test "invalid empty message" do
    encoded =
      %Call{}
      |> Call.encode
    assert AMQPServer.process_rpc(encoded) == {:error, :empty_call}
  end

  test "GetInfo call" do
    encoded =
      %Call{call: {:get_info, %GetInfo{}}}
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    expected_reply =
      %Reply{reply:
        {:get_info_reply, %GetInfoReply{url: Config.broker_url!(), version: Mix.Project.config[:version]}}}

    assert Reply.decode(reply) == expected_reply
  end
end
