defmodule Astarte.RealmManagement.RPC.AMQPServerTest do
  use ExUnit.Case
  require Logger

  test "process_rpc invalid messages and calls" do
    assert_raise FunctionClauseError, fn -> Astarte.RealmManagement.RPC.AMQPServer.process_rpc(nil) end
    assert_raise FunctionClauseError, fn -> assert Astarte.RealmManagement.RPC.AMQPServer.process_rpc([]) end
    assert Astarte.RealmManagement.RPC.AMQPServer.process_rpc("") == {:error, :unexpected_message}
  end
end
