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

  @self_signed_crt """
  -----BEGIN CERTIFICATE-----
  MIIFfzCCA2egAwIBAgIJALsySXafOY1aMA0GCSqGSIb3DQEBCwUAMFYxCzAJBgNV
  BAYTAklUMRAwDgYDVQQIDAdFeGFtcGxlMSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRn
  aXRzIFB0eSBMdGQxEjAQBgNVBAMMCXRlc3QvaHdpZDAeFw0xNzEwMTgxNTE2MzBa
  Fw0xODEwMTgxNTE2MzBaMFYxCzAJBgNVBAYTAklUMRAwDgYDVQQIDAdFeGFtcGxl
  MSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQxEjAQBgNVBAMMCXRl
  c3QvaHdpZDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKVsOtA5JoWo
  nOF7BASELrkbus/miu9ySu9u/DtQyrsQcUm5dYHbI0jET9CQv+mI46oNzNDkhQUJ
  +1d82fYgd8mkSglKE8QValmIDJzEwRTMVhsj8i8UydwAiuj0wRuW+hHZw1t3kLXL
  4e/CsLBejqKXAWBLxpDgYNulU5c11Dzof7+So8m/y1Kg9TMCgqF979u1jlHA19x8
  PVeUeAcFvrjiV+cr4XbzNCGBMH1f/bm93dBJjbOEuSVCEm4XE5XnvRT3hWSSp3eV
  9P1uRCNyUTkFuru/f/bkVQsvO+YU39IlNePIEozjvdiZeqXqAmei4JugLWhq/Qwy
  skCS/7avlOmgbGjJd8zSGAAl8/0hUH4YkJ4zcvp7rzc/Ze/E7VJuQOrxbmCpaIBo
  C8s3geMCu+7vzyixkgtvG6lWrX7xzMKPbAX5ciBXYMiNIB14GSlPEn6RqFmPnB0Z
  azUtMY8qYVSPSGo12vuWCt6grCh3cpFakWg6LnviW035iClPhup6JXs42jb1UMZv
  kY9eNWICJ+mOZYBEVgFqL5cTVwRis7ZDkBvcuhEOxn6OwkicQuvTWhmFNDttZM9M
  0YAvGzdQU6mtqH7GOHjqi5hSrZ8vthi275jL9sQv9fuEtjTM6r3zE+sFgwTbxSeq
  Rk2M/smGcy8NMfke63j/NFCKcAJeexkLAgMBAAGjUDBOMB0GA1UdDgQWBBTpVKpD
  FWDodB9WohGhL6Q3kMUITDAfBgNVHSMEGDAWgBTpVKpDFWDodB9WohGhL6Q3kMUI
  TDAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBCwUAA4ICAQAxlhkVPkKv2mKvXspj
  codSBTfIBMV+TdlwKKT+3A71k0fpS3HSvH98lLxkZLHPQuTi4/hpscITzvdfyLnG
  HFRrCwc3v2x8d3/Fny7MPJu+5HLRMdDXVOSQXOUcA+P1KwibXWwp6GG8kZJ+VWAW
  eRiOFwptBje8tdeF3YkEHS5GJ92DOyUc6As2UjCu+Psx0cB5Kevny4XFcekUs1Bd
  hYH1Hnr/WFZJQJz68Bp+APr36UusQRo7a4YrOwnlYszGqrZQtQNRY8XVP5pC/YhD
  cVtXOyU9NkCPlvxsCdTXObeQq38yxLm6gXi3cJBb1eAL0tBAXky0sLrzOHq462Cn
  nzvGySpFjMtO4ZTK9hOp4o9/vXx2U/AWk62yCrhDtD8mlV+ljIbw2V6rFJsFnBsX
  DFG3ljCR7sW+YCLtn/Fig/H07alBr3GiTjAG8vCSMAbvk/QMs1MNEj55FpXY/B6h
  EXK2dEY+KPwMSBSwxrrZ74BXw0TWcwTVTRpkmtZ8qLTnXYOQ5kYKJ+aDR389+Vy6
  d4NjjktgugxaL4tGkSMwiinZbBeG9oxtOgZOKQ/W+K1qzCb2ySH2hk5NTdbt7fQX
  1o2dS9VvunQFSNA8diqBSOjuyoEuR6qo1ejF0o7KW6cJWMsvqq+awKuNmqM7yG59
  ySj0xif2Z8U7MTfhmZs1cyDA/A==
  -----END CERTIFICATE-----
  """

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

    test "valid call with VerifyCertificate", %{api_key: api_key} do
      encoded =
        %Call{call: {:do_pairing, %DoPairing{api_key: api_key, csr: @test_csr, device_ip: "2.3.4.5"}}}
        |> Call.encode()

      {:ok, reply} = AMQPServer.process_rpc(encoded)

      assert %Reply{reply: {:do_pairing_reply, %DoPairingReply{client_crt: client_crt}}} = Reply.decode(reply)

      encoded_verify =
        %Call{call: {:verify_certificate, %VerifyCertificate{crt: client_crt}}}
        |> Call.encode()

      {:ok, verify_reply} = AMQPServer.process_rpc(encoded_verify)

      assert match?(%Reply{reply: {:verify_certificate_reply, %VerifyCertificateReply{valid: true, timestamp: _ts, until: _until}}},
                    Reply.decode(verify_reply))
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

  test "VerifyCertificate fail with self signed crt" do
    encoded =
      %Call{call: {:verify_certificate, %VerifyCertificate{crt: @self_signed_crt}}}
      |> Call.encode()

    {:ok, verify_reply} = AMQPServer.process_rpc(encoded)

    assert %Reply{reply: {:verify_certificate_reply, %VerifyCertificateReply{valid: false, cause: :INVALID_ISSUER}}} == Reply.decode(verify_reply)
  end
end
