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

defmodule Astarte.Pairing.APIWeb.DeviceControllerTest do
  use Astarte.Pairing.APIWeb.ConnCase

  alias Astarte.RPC.Protocol.Pairing.{
    AstarteMQTTV1Credentials,
    AstarteMQTTV1CredentialsStatus,
    AstarteMQTTV1Status,
    GenericErrorReply,
    GetCredentialsReply,
    GetInfoReply,
    ProtocolStatus,
    Reply,
    VerifyCredentialsReply
  }

  import Mox

  @realm "testrealm"
  @hw_id "o9RQb8B-R8WY_N7kR56M2w"
  @csr """
  -----BEGIN CERTIFICATE REQUEST-----
  MIICwTCCAakCAQAwfDELMAkGA1UEBhMCQVUxEzARBgNVBAgMClNvbWUtU3RhdGUx
  DTALBgNVBAcMBGNpdHkxITAfBgNVBAoMGEludGVybmV0IFdpZGdpdHMgUHR5IEx0
  ZDEQMA4GA1UECwwHc2VjdGlvbjEUMBIGA1UEAwwLZXhhbXBsZS5jb20wggEiMA0G
  CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC1neUXJSjPdfUDVNRDMDGapwnRqsfO
  FbEMcm1+q4yav5OxbdHRrFjeKheJyUeoIySdzs4gncZEAaLWqXoxN4xNiH5EYUJW
  BDV/SYJSpXFlSdDcidOZ4fUKCRU5NIoGAQEfU9wFPr6V7Q5c/U5GB4PG12i5i4i7
  9gyNn0SdFezIkSxPdpzi0Wn+icBvH/9JKJ+IWi2yV7EI6/tUy9xnC46ejpeD267x
  YhCwV4rjX5Xs3dirhipxVYbCa1QE+VY3B8yCTKuiYUTySJQt2VFj7zQe4Y26EzSP
  4AoVi1sSNbL8bs8KCWSblMJpjctRclRx/c1zwy61BW7oYuujf2R5v561AgMBAAGg
  ADANBgkqhkiG9w0BAQsFAAOCAQEASZatzkHf2YqRBT3BrQ/8kW5ghWKUj8E9pJXV
  DF4XOwe9npybtDAJLXmSnsWWKnb3N2LYWJYsp29hi04JnGXGPg9BurWXSrHlExPK
  2uRh+VZomz4i0/bMgVbL3yLYTKKa7qkM1smU4PoI+QB0qbEZADX7HOJ36cycpNV+
  AOlub1IrAOIXR529VW5nYMlSO+vbK9qSpVFyHfizbRr8pu80oI1ELOqAMEGzPotT
  Xp9mlocowXfe+8dFLaV11fuFdUMGeSXfzcYRVRGsCmLWwpMHil0TWaeissKnxqNz
  nBWYJpUTEDTAbDYx4F9YwSfuXrA9jCABgZw92ggqnh2dzRQWSw==
  -----END CERTIFICATE REQUEST-----
  """

  @secret "supersecret"
  @client_crt "not exactly a certificate"

  @rpc_destination Astarte.RPC.Protocol.Pairing.amqp_queue()

  describe "create Astarte MQTT V1 credentials" do
    @create_attrs %{"csr" => @csr}
    @invalid_attrs %{}

    @encoded_credentials_response %Reply{
                                    reply:
                                      {:get_credentials_reply,
                                       %GetCredentialsReply{
                                         credentials:
                                           {:astarte_mqtt_v1,
                                            %AstarteMQTTV1Credentials{client_crt: @client_crt}}
                                       }}
                                  }
                                  |> Reply.encode()

    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "bearer #{@secret}")
        |> put_resp_header("accept", "application/json")

      {:ok, conn: conn}
    end

    test "renders credentials when data is valid", %{conn: conn} do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination ->
        {:ok, @encoded_credentials_response}
      end)

      conn =
        post(
          conn,
          device_path(conn, :create_credentials, @realm, @hw_id, "astarte_mqtt_v1"),
          data: @create_attrs
        )

      assert %{"client_crt" => @client_crt} = json_response(conn, 201)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(
          conn,
          device_path(conn, :create_credentials, @realm, @hw_id, "astarte_mqtt_v1"),
          data: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when no authorization header", %{conn: conn} do
      conn =
        conn
        |> delete_req_header("authorization")
        |> post(
          device_path(conn, :create_credentials, @realm, @hw_id, "astarte_mqtt_v1"),
          data: @create_attrs
        )

      assert json_response(conn, 401)["errors"] == %{"detail" => "Unauthorized"}
    end

    test "renders errors when forbidden", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "invalidsecret")
        |> post(
          device_path(conn, :create_credentials, @realm, @hw_id, "astarte_mqtt_v1"),
          data: @create_attrs
        )

      assert json_response(conn, 401)["errors"] == %{"detail" => "Unauthorized"}
    end
  end

  describe "verify Astarte MQTT V1 credentials" do
    @expired_client_crt "expired crt"

    @verify_attrs %{"client_crt" => @client_crt}
    @expired_crt_attrs %{"client_crt" => @expired_client_crt}
    @invalid_attrs %{"client_crt" => ""}

    @now DateTime.utc_now() |> DateTime.to_unix(:milliseconds)
    @one_month_from_now 2_678_400_000 + @now

    @encoded_verify_valid_response %Reply{
                                     reply:
                                       {:verify_credentials_reply,
                                        %VerifyCredentialsReply{
                                          credentials_status:
                                            {:astarte_mqtt_v1,
                                             %AstarteMQTTV1CredentialsStatus{
                                               valid: true,
                                               timestamp: @now,
                                               until: @one_month_from_now
                                             }}
                                        }}
                                   }
                                   |> Reply.encode()

    @encoded_verify_not_valid_response %Reply{
                                         reply:
                                           {:verify_credentials_reply,
                                            %VerifyCredentialsReply{
                                              credentials_status:
                                                {:astarte_mqtt_v1,
                                                 %AstarteMQTTV1CredentialsStatus{
                                                   valid: false,
                                                   timestamp: @now,
                                                   cause: :EXPIRED
                                                 }}
                                            }}
                                       }
                                       |> Reply.encode()

    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "bearer #{@secret}")
        |> put_resp_header("accept", "application/json")

      {:ok, conn: conn}
    end

    test "renders credentials status when data is valid", %{conn: conn} do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination ->
        {:ok, @encoded_verify_valid_response}
      end)

      conn =
        post(
          conn,
          device_path(conn, :verify_credentials, @realm, @hw_id, "astarte_mqtt_v1"),
          data: @verify_attrs
        )

      assert %{"valid" => true, "timestamp" => @now, "until" => @one_month_from_now} =
               json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(
          conn,
          device_path(conn, :verify_credentials, @realm, @hw_id, "astarte_mqtt_v1"),
          data: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders credentials status when credentials are invalid", %{conn: conn} do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination ->
        {:ok, @encoded_verify_not_valid_response}
      end)

      conn =
        post(
          conn,
          device_path(conn, :verify_credentials, @realm, @hw_id, "astarte_mqtt_v1"),
          data: @expired_crt_attrs
        )

      assert %{
               "valid" => false,
               "timestamp" => @now,
               "cause" => "EXPIRED",
               "details" => nil
             } = json_response(conn, 200)["data"]
    end
  end

  describe "get device info" do
    @version "0.1.0"
    @status "pending"
    @broker_url "ssl://broker.example.com"

    @encoded_info_response %Reply{
                             reply:
                               {:get_info_reply,
                                %GetInfoReply{
                                  version: @version,
                                  device_status: @status,
                                  protocols: [
                                    %ProtocolStatus{
                                      status:
                                        {:astarte_mqtt_v1,
                                         %AstarteMQTTV1Status{
                                           broker_url: @broker_url
                                         }}
                                    }
                                  ]
                                }}
                           }
                           |> Reply.encode()

    @encoded_forbidden_response %Reply{
                                  reply:
                                    {:generic_error_reply,
                                     %GenericErrorReply{error_name: "forbidden"}}
                                }
                                |> Reply.encode()

    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "bearer #{@secret}")
        |> put_resp_header("accept", "application/json")

      {:ok, conn: conn}
    end

    test "renders info status", %{conn: conn} do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination ->
        {:ok, @encoded_info_response}
      end)

      conn = get(conn, device_path(conn, :show_info, @realm, @hw_id))

      assert %{"version" => @version, "status" => @status, "protocols" => protocols} =
               json_response(conn, 200)["data"]

      assert %{"astarte_mqtt_v1" => %{"broker_url" => @broker_url}} = protocols
    end

    test "renders error with invalid secret", %{conn: conn} do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination ->
        {:ok, @encoded_forbidden_response}
      end)

      conn = get(conn, device_path(conn, :show_info, @realm, @hw_id))
      assert json_response(conn, 403)["errors"] == %{"detail" => "Forbidden"}
    end
  end
end
