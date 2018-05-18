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
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.Pairing.RPC.HandlerTest do
  use ExUnit.Case

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.DatabaseTestHelper

  alias Astarte.Pairing.RPC.Handler

  alias Astarte.RPC.Protocol.Pairing.{
    AstarteMQTTV1Credentials,
    AstarteMQTTV1CredentialsParameters,
    AstarteMQTTV1CredentialsStatus,
    AstarteMQTTV1Status,
    Call,
    GenericErrorReply,
    GetCredentials,
    GetCredentialsReply,
    GetInfo,
    GetInfoReply,
    ProtocolStatus,
    RegisterDevice,
    RegisterDeviceReply,
    Reply,
    VerifyCredentials,
    VerifyCredentialsReply
  }

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
    DatabaseTestHelper.create_db()

    on_exit(fn ->
      DatabaseTestHelper.drop_db()
    end)
  end

  test "invalid empty message" do
    encoded =
      %Call{}
      |> Call.encode()

    assert Handler.handle_rpc(encoded) == {:error, :empty_call}
  end

  describe "GetInfo" do
    setup do
      DatabaseTestHelper.seed_devices()

      on_exit(fn ->
        DatabaseTestHelper.clean_devices()
      end)

      hw_id = DatabaseTestHelper.registered_not_confirmed_hw_id()
      secret = DatabaseTestHelper.registered_not_confirmed_credentials_secret()

      {:ok, hw_id: hw_id, secret: secret}
    end

    test "fails with invalid realm", %{hw_id: hw_id, secret: secret} do
      encoded =
        %Call{call: {:get_info, %GetInfo{realm: "invalid", hw_id: hw_id, secret: secret}}}
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      expected_err_reply = %Reply{
        error: true,
        reply: {:generic_error_reply, %GenericErrorReply{error_name: "realm_not_found"}}
      }

      assert Reply.decode(reply) == expected_err_reply
    end

    test "successful call with pending device", %{hw_id: hw_id, secret: secret} do
      encoded =
        %Call{call: {:get_info, %GetInfo{realm: @test_realm, hw_id: hw_id, secret: secret}}}
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      broker_url = Config.broker_url!()

      assert %Reply{
               error: false,
               reply:
                 {:get_info_reply,
                  %GetInfoReply{version: _version, device_status: "pending", protocols: protocols}}
             } = Reply.decode(reply)

      assert [
               %ProtocolStatus{
                 status: {:astarte_mqtt_v1, %AstarteMQTTV1Status{broker_url: ^broker_url}}
               }
             ] = protocols
    end

    test "successful call with registered device" do
      hw_id = DatabaseTestHelper.registered_and_confirmed_hw_id()
      secret = DatabaseTestHelper.registered_and_confirmed_credentials_secret()

      encoded =
        %Call{call: {:get_info, %GetInfo{realm: @test_realm, hw_id: hw_id, secret: secret}}}
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      broker_url = Config.broker_url!()

      assert %Reply{
               error: false,
               reply:
                 {:get_info_reply,
                  %GetInfoReply{
                    version: _version,
                    device_status: "confirmed",
                    protocols: protocols
                  }}
             } = Reply.decode(reply)

      assert [
               %ProtocolStatus{
                 status: {:astarte_mqtt_v1, %AstarteMQTTV1Status{broker_url: ^broker_url}}
               }
             ] = protocols
    end
  end

  describe "RegisterDevice" do
    setup do
      on_exit(fn ->
        DatabaseTestHelper.clean_devices()
      end)
    end

    test "successful call" do
      encoded =
        %Call{call: {:register_device, %RegisterDevice{realm: @test_realm, hw_id: @test_hw_id_1}}}
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      assert %Reply{
               reply: {:register_device_reply, %RegisterDeviceReply{credentials_secret: _secret}}
             } = Reply.decode(reply)
    end

    test "can register the same device twice" do
      encoded =
        %Call{call: {:register_device, %RegisterDevice{realm: @test_realm, hw_id: @test_hw_id_2}}}
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      assert %Reply{
               reply:
                 {:register_device_reply, %RegisterDeviceReply{credentials_secret: first_secret}}
             } = Reply.decode(reply)

      # register the device again
      {:ok, reply} = Handler.handle_rpc(encoded)

      assert %Reply{
               reply:
                 {:register_device_reply, %RegisterDeviceReply{credentials_secret: second_secret}}
             } = Reply.decode(reply)

      assert first_secret != second_secret
    end

    test "can't register the same device twice if it asks for credentials" do
      encoded =
        %Call{call: {:register_device, %RegisterDevice{realm: @test_realm, hw_id: @test_hw_id_2}}}
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      assert %Reply{
               reply: {:register_device_reply, %RegisterDeviceReply{credentials_secret: secret}}
             } = Reply.decode(reply)

      encoded_cred =
        %Call{
          call:
            {:get_credentials,
             %GetCredentials{
               realm: @test_realm,
               hw_id: @test_hw_id_2,
               secret: secret,
               device_ip: "2.3.5.6",
               credentials_parameters:
                 {:astarte_mqtt_v1,
                  %AstarteMQTTV1CredentialsParameters{
                    csr: @test_csr
                  }}
             }}
        }
        |> Call.encode()

      {:ok, cred_reply} = Handler.handle_rpc(encoded_cred)

      assert %Reply{
               reply:
                 {:get_credentials_reply,
                  %GetCredentialsReply{
                    credentials: _credentials
                  }}
             } = Reply.decode(cred_reply)

      # Try to register the device again
      {:ok, reply} = Handler.handle_rpc(encoded)

      assert %Reply{
               reply: {:generic_error_reply, %GenericErrorReply{error_name: "already_registered"}}
             } = Reply.decode(reply)
    end

    test "fails with invalid hw_id" do
      encoded =
        %Call{
          call: {:register_device, %RegisterDevice{realm: @test_realm, hw_id: "invalid_hw_id"}}
        }
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      expected_err_reply = %Reply{
        error: true,
        reply: {:generic_error_reply, %GenericErrorReply{error_name: "invalid_device_id"}}
      }

      assert expected_err_reply == Reply.decode(reply)
    end
  end

  describe "GetCredentials" do
    setup do
      DatabaseTestHelper.seed_devices()

      on_exit(fn ->
        DatabaseTestHelper.clean_devices()
      end)

      hw_id = DatabaseTestHelper.registered_not_confirmed_hw_id()
      secret = DatabaseTestHelper.registered_not_confirmed_credentials_secret()

      {:ok, hw_id: hw_id, secret: secret}
    end

    test "valid call with VerifyCredentials", %{hw_id: hw_id, secret: secret} do
      encoded =
        %Call{
          call:
            {:get_credentials,
             %GetCredentials{
               realm: @test_realm,
               hw_id: hw_id,
               secret: secret,
               device_ip: "2.3.4.5",
               credentials_parameters:
                 {:astarte_mqtt_v1, %AstarteMQTTV1CredentialsParameters{csr: @test_csr}}
             }}
        }
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      assert %Reply{
               reply: {:get_credentials_reply, %GetCredentialsReply{credentials: credentials}}
             } = Reply.decode(reply)

      encoded_verify =
        %Call{
          call:
            {:verify_credentials,
             %VerifyCredentials{
               realm: @test_realm,
               hw_id: hw_id,
               secret: secret,
               credentials: credentials
             }}
        }
        |> Call.encode()

      {:ok, verify_reply} = Handler.handle_rpc(encoded_verify)

      assert %Reply{
               reply:
                 {:verify_credentials_reply,
                  %VerifyCredentialsReply{
                    credentials_status:
                      {:astarte_mqtt_v1,
                       %AstarteMQTTV1CredentialsStatus{valid: true, timestamp: _ts, until: _until}}
                  }}
             } = Reply.decode(verify_reply)
    end

    test "invalid call", %{hw_id: hw_id, secret: secret} do
      invalid_ip = "300.3.4.5"

      encoded =
        %Call{
          call:
            {:get_credentials,
             %GetCredentials{
               realm: @test_realm,
               hw_id: hw_id,
               secret: secret,
               device_ip: invalid_ip,
               credentials_parameters:
                 {:astarte_mqtt_v1, %AstarteMQTTV1CredentialsParameters{csr: @test_csr}}
             }}
        }
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      expected_err_reply = %Reply{
        error: true,
        reply: {:generic_error_reply, %GenericErrorReply{error_name: "invalid_ip"}}
      }

      assert expected_err_reply == Reply.decode(reply)
    end
  end

  describe "VerifyCredentials" do
    setup do
      DatabaseTestHelper.seed_devices()

      on_exit(fn ->
        DatabaseTestHelper.clean_devices()
      end)

      hw_id = DatabaseTestHelper.registered_and_confirmed_hw_id()
      secret = DatabaseTestHelper.registered_and_confirmed_credentials_secret()

      {:ok, hw_id: hw_id, secret: secret}
    end

    test "fails with self signed crt", %{hw_id: hw_id, secret: secret} do
      encoded =
        %Call{
          call:
            {:verify_credentials,
             %VerifyCredentials{
               realm: @test_realm,
               hw_id: hw_id,
               secret: secret,
               credentials:
                 {:astarte_mqtt_v1, %AstarteMQTTV1Credentials{client_crt: @self_signed_crt}}
             }}
        }
        |> Call.encode()

      {:ok, verify_reply} = Handler.handle_rpc(encoded)

      assert %Reply{
               reply:
                 {:verify_credentials_reply,
                  %VerifyCredentialsReply{
                    credentials_status:
                      {:astarte_mqtt_v1,
                       %AstarteMQTTV1CredentialsStatus{
                         valid: false,
                         cause: :INVALID_ISSUER,
                         timestamp: _timestamp
                       }}
                  }}
             } = Reply.decode(verify_reply)
    end
  end
end
