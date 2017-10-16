defmodule Astarte.Pairing.RPC.AMQPServerTest do
  use ExUnit.Case

  alias Astarte.Pairing.APIKey
  alias Astarte.Pairing.Config
  alias Astarte.Pairing.DatabaseTestHelper
  alias Astarte.Pairing.RPC.AMQPServer
  alias Astarte.Pairing.Utils

  use Astarte.RPC.Protocol.Pairing

  @test_hw_id_1 :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  @test_hw_id_2 :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

  setup_all do
    DatabaseTestHelper.seed_db()

    on_exit fn ->
      DatabaseTestHelper.drop_db()
    end
  end

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

  test "GenerateAPIKey call" do
    encoded =
      %Call{call: {:generate_api_key, %GenerateAPIKey{realm: DatabaseTestHelper.test_realm(), hw_id: @test_hw_id_1}}}
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    {:ok, device_uuid} = Utils.extended_id_to_uuid(@test_hw_id_1)
    {:ok, expected_api_key} = APIKey.generate(DatabaseTestHelper.test_realm(), device_uuid, "api_salt")

    expected_reply =
      %Reply{reply:
        {:generate_api_key_reply, %GenerateAPIKeyReply{api_key: expected_api_key}}}

    assert Reply.decode(reply) == expected_reply
  end

  test "GenerateAPIKey can't insert the same device twice" do
    encoded =
      %Call{call: {:generate_api_key, %GenerateAPIKey{realm: DatabaseTestHelper.test_realm(), hw_id: @test_hw_id_2}}}
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    {:ok, device_uuid} = Utils.extended_id_to_uuid(@test_hw_id_2)
    {:ok, expected_api_key} = APIKey.generate(DatabaseTestHelper.test_realm(), device_uuid, "api_salt")

    expected_reply =
      %Reply{reply:
        {:generate_api_key_reply, %GenerateAPIKeyReply{api_key: expected_api_key}}}

    assert Reply.decode(reply) == expected_reply

    # Try to generate the APIKey again
    {:ok, reply} = AMQPServer.process_rpc(encoded)

    expected_err_reply =
      %Reply{error: true, reply: {:generic_error_reply, %GenericErrorReply{error_name: "device_exists"}}}

    assert expected_err_reply == Reply.decode(reply)
  end

  test "GenerateAPIKey fails with invalid hw_id" do
    encoded =
      %Call{call: {:generate_api_key, %GenerateAPIKey{realm: DatabaseTestHelper.test_realm(), hw_id: "invalid_hw_id"}}}
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    expected_err_reply =
      %Reply{error: true, reply: {:generic_error_reply, %GenericErrorReply{error_name: "id_decode_failed"}}}

    assert expected_err_reply == Reply.decode(reply)
  end
end
