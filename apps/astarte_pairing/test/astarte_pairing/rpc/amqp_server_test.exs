defmodule Astarte.Pairing.RPC.AMQPServerTest do
  use ExUnit.Case

  alias Astarte.Pairing.APIKey
  alias Astarte.Pairing.Config
  alias Astarte.Pairing.DatabaseTestHelper
  alias Astarte.Pairing.Engine
  alias Astarte.Pairing.TestHelper
  alias Astarte.Pairing.RPC.AMQPServer
  alias Astarte.Pairing.Utils

  use Astarte.RPC.Protocol.Pairing

  @test_hw_id_1 :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  @test_hw_id_2 :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

  @test_csr """
  -----BEGIN CERTIFICATE REQUEST-----
  MIICnTCCAYUCAQAwWDELMAkGA1UEBhMCSVQxFDASBgNVBAgMC0V4YW1wbGVMYW5k
  MSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQxEDAOBgNVBAMMB0V4
  YW1wbGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC6B6eGPsTLsP09
  FzxFUKY95GaPnBU1niq1tx1vtA+r9BBnnoUn4JwNHtu5YTWMnlIJtfAs43ltLOrS
  Wyvcedg4e6Bh3nztqyD+4uSpzlSI54zexbztVAzzDvVlEuW0wMRgkqF7ez7OixGF
  BHdPgWKTxagVrYdqX/UjNm9f/Wnd3eCA9mEVwsARUlxRgLs0KPXPkqEGCxbcLSx3
  lJR28YE+OTJK7aLSUk3bjLml23SYhWSlmYbNghu3/2P3n4QO4s6+RAw1bMxEO0xr
  gvZThRcdllw+SQRY03VHzCiAAAYzKR8upy5strSbQfG9D38xHGb+A/Z6oSaJp4tR
  m+VknzINAgMBAAGgADANBgkqhkiG9w0BAQsFAAOCAQEALvDY6irBZJXuJ+AZ/5rL
  EEpWXl3f6ohdGkUE9oZFBsNQkCyejQbwYF4ujmxI7CqhZFrX6TA6KkjzDuWwqezt
  YcyYYBgxF8+HUO/66jseGuJiuPkeDQ5e2Kghit8PPutv9I1OVPaQkbNg6aDvaANT
  oB9IilYaxWM6en+RdtSg6p5dysfgOM3GbWqIjjZgU1rZsiuTOPRjxzXLc4Vq0v/A
  MvsV2OFBjcOPfqeTwuegl16reSy9+x79zmSfzapoji90Cc1hBQgqvPYCezEeuj+i
  hXQ3OSmKiyvSLJekdmgqdjsu7ks49Tm7wSUKC0QxlDh54k5Yo8uDM+4MLvOZOzL3
  FQ==
  -----END CERTIFICATE REQUEST-----
  """

  @test_realm DatabaseTestHelper.test_realm()

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
      %Call{call: {:generate_api_key, %GenerateAPIKey{realm: @test_realm, hw_id: @test_hw_id_1}}}
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    {:ok, device_uuid} = Utils.extended_id_to_uuid(@test_hw_id_1)
    {:ok, expected_api_key} = APIKey.generate(@test_realm, device_uuid, "api_salt")

    expected_reply =
      %Reply{reply:
        {:generate_api_key_reply, %GenerateAPIKeyReply{api_key: expected_api_key}}}

    assert Reply.decode(reply) == expected_reply
  end

  test "GenerateAPIKey can't insert the same device twice" do
    encoded =
      %Call{call: {:generate_api_key, %GenerateAPIKey{realm: @test_realm, hw_id: @test_hw_id_2}}}
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    {:ok, device_uuid} = Utils.extended_id_to_uuid(@test_hw_id_2)
    {:ok, expected_api_key} = APIKey.generate(@test_realm, device_uuid, "api_salt")

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
      %Call{call: {:generate_api_key, %GenerateAPIKey{realm: @test_realm, hw_id: "invalid_hw_id"}}}
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    expected_err_reply =
      %Reply{error: true, reply: {:generic_error_reply, %GenericErrorReply{error_name: "id_decode_failed"}}}

    assert expected_err_reply == Reply.decode(reply)
  end

  describe "DoPairing" do
    setup do
      hw_id = TestHelper.random_hw_id()
      {:ok, api_key} = Engine.generate_api_key(@test_realm, hw_id)

      {:ok, api_key: api_key}
    end

    test "valid call", %{api_key: api_key} do
      encoded =
        %Call{call: {:do_pairing, %DoPairing{api_key: api_key, csr: @test_csr, device_ip: "2.3.4.5"}}}
        |> Call.encode()

      {:ok, reply} = AMQPServer.process_rpc(encoded)

      assert match?(%Reply{reply: {:do_pairing_reply, %DoPairingReply{client_crt: _client_crt}}},
                    Reply.decode(reply))
    end

    test "invalid call", %{api_key: api_key} do
      invalid_ip = "300.3.4.5"

      encoded =
        %Call{call: {:do_pairing, %DoPairing{api_key: api_key, csr: @test_csr, device_ip: invalid_ip}}}
        |> Call.encode()

      {:ok, reply} = AMQPServer.process_rpc(encoded)

      expected_err_reply =
        %Reply{error: true, reply: {:generic_error_reply, %GenericErrorReply{error_name: "invalid_ip"}}}

      assert expected_err_reply == Reply.decode(reply)
    end
  end
end
