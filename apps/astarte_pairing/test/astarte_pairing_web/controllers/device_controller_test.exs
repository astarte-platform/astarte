#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.PairingWeb.DeviceControllerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Astarte.PairingWeb.ConnCase, async: true

  import Astarte.Helpers.Device

  @secret "supersecret"

  @ca_cert """
  -----BEGIN CERTIFICATE-----
  MIICNTCCAdqgAwIBAgIUIOSSE9sxXZWckOs+jtq+wBiGCiIwCgYIKoZIzj0EAwIw
  dzELMAkGA1UEBhMCVVMxDzANBgNVBAgTBk5ldmFkYTESMBAGA1UEBxMJTGFzIFZl
  Z2FzMRgwFgYDVQQKEw9FeGFtcGxlIENvbXBhbnkxFDASBgNVBAsTC0NBIFNlcnZp
  Y2VzMRMwEQYDVQQDEwpNeSBSb290IENBMCAXDTI1MDYyNDA3MTgwMFoYDzIwNTUw
  NjE3MDcxODAwWjB3MQswCQYDVQQGEwJVUzEPMA0GA1UECBMGTmV2YWRhMRIwEAYD
  VQQHEwlMYXMgVmVnYXMxGDAWBgNVBAoTD0V4YW1wbGUgQ29tcGFueTEUMBIGA1UE
  CxMLQ0EgU2VydmljZXMxEzARBgNVBAMTCk15IFJvb3QgQ0EwWTATBgcqhkjOPQIB
  BggqhkjOPQMBBwNCAARdrgh5v5PtcHlVD+0j4rQnDPHLsyx3PI9SRIfoO5X2r69X
  Fj4ZPCoMaavhUjcjmeh62KFdtPdzwDucNPpo60Zxo0IwQDAOBgNVHQ8BAf8EBAMC
  AQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUshI4rsI0qYhfHVALQb4TeItb
  78YwCgYIKoZIzj0EAwIDSQAwRgIhAID+zw34Tkz0O5UCrSlxM9+ud+P9/mpjbePn
  aqkyw+ahAiEA1u/5NagV9BX2PbMQzkjywdby+z42udBTEzUgZrOWpLQ=
  -----END CERTIFICATE-----
  """
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
  @client_crt """
  -----BEGIN CERTIFICATE-----
  MIIDSTCCAvCgAwIBAgIUZ0Rnyy9sfanGRUzF8nOf8iG8nvswCgYIKoZIzj0EAwIw
  dzELMAkGA1UEBhMCVVMxDzANBgNVBAgTBk5ldmFkYTESMBAGA1UEBxMJTGFzIFZl
  Z2FzMRgwFgYDVQQKEw9FeGFtcGxlIENvbXBhbnkxFDASBgNVBAsTC0NBIFNlcnZp
  Y2VzMRMwEQYDVQQDEwpNeSBSb290IENBMB4XDTI1MDYyNDA5MTIwMFoXDTI1MDgy
  MzA5MTIwMFowgZAxCzAJBgNVBAYTAkFVMRMwEQYDVQQIEwpTb21lLVN0YXRlMQ0w
  CwYDVQQHEwRjaXR5MSEwHwYDVQQKExhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQx
  EDAOBgNVBAsTB3NlY3Rpb24xKDAmBgNVBAMTH3JlYWxtMTMxL1gxOEVwV2lmUk9t
  RnFMazVwWDlZZkEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC1neUX
  JSjPdfUDVNRDMDGapwnRqsfOFbEMcm1+q4yav5OxbdHRrFjeKheJyUeoIySdzs4g
  ncZEAaLWqXoxN4xNiH5EYUJWBDV/SYJSpXFlSdDcidOZ4fUKCRU5NIoGAQEfU9wF
  Pr6V7Q5c/U5GB4PG12i5i4i79gyNn0SdFezIkSxPdpzi0Wn+icBvH/9JKJ+IWi2y
  V7EI6/tUy9xnC46ejpeD267xYhCwV4rjX5Xs3dirhipxVYbCa1QE+VY3B8yCTKui
  YUTySJQt2VFj7zQe4Y26EzSP4AoVi1sSNbL8bs8KCWSblMJpjctRclRx/c1zwy61
  BW7oYuujf2R5v561AgMBAAGjdTBzMA4GA1UdDwEB/wQEAwIFoDATBgNVHSUEDDAK
  BggrBgEFBQcDAjAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBR1XskiVL9asyf6ceUr
  yteHWMkxEDAfBgNVHSMEGDAWgBSyEjiuwjSpiF8dUAtBvhN4i1vvxjAKBggqhkjO
  PQQDAgNHADBEAiAC+24qHLC/b+xnuXO/pYCXFnA8GsdfHI3zBQbMvgzlRQIgAoEX
  3JUIkrX38f7JqgQ6BX3YXfH79iiPvhx9uhYrlTc=
  -----END CERTIFICATE-----
  """

  setup :set_ca_cert

  defp set_ca_cert(_ctx) do
    Mimic.stub(Astarte.Pairing.Config, :ca_cert!, fn -> @ca_cert end)

    :ok
  end

  describe "create Astarte MQTT V1 credentials" do
    @create_attrs %{"csr" => @csr}
    @invalid_attrs %{}

    setup %{conn: conn, realm_name: realm_name, device: device} do
      update_credentials_secret!(realm_name, device.id, @secret)
      update_device!(realm_name, device.id, inhibit_credentials_request: false)

      conn =
        conn
        |> put_req_header("authorization", "bearer #{@secret}")
        |> put_resp_header("accept", "application/json")

      {:ok, conn: conn}
    end

    test "renders credentials when data is valid", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      conn =
        post(
          conn,
          device_path(
            conn,
            :create_credentials,
            realm_name,
            device.encoded_id,
            "astarte_mqtt_v1"
          ),
          data: @create_attrs
        )

      assert %{"client_crt" => client_crt} = json_response(conn, 201)["data"]

      assert client_crt =~ "-----BEGIN CERTIFICATE-----"
    end

    test "renders errors when data is invalid", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      conn =
        post(
          conn,
          device_path(
            conn,
            :create_credentials,
            realm_name,
            device.encoded_id,
            "astarte_mqtt_v1"
          ),
          data: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when no authorization header", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      conn =
        conn
        |> delete_req_header("authorization")
        |> post(
          device_path(
            conn,
            :create_credentials,
            realm_name,
            device.encoded_id,
            "astarte_mqtt_v1"
          ),
          data: @create_attrs
        )

      assert json_response(conn, 401)["errors"] == %{"detail" => "Unauthorized"}
    end

    test "renders errors when forbidden", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      conn =
        conn
        |> put_req_header("authorization", "invalidsecret")
        |> post(
          device_path(
            conn,
            :create_credentials,
            realm_name,
            device.encoded_id,
            "astarte_mqtt_v1"
          ),
          data: @create_attrs
        )

      assert json_response(conn, 401)["errors"] == %{"detail" => "Unauthorized"}
    end

    test "renders forbidden error when realm does not exist", ctx do
      %{conn: conn, device: device} = ctx

      realm_name = "unknown"

      conn =
        post(
          conn,
          device_path(
            conn,
            :create_credentials,
            realm_name,
            device.encoded_id,
            "astarte_mqtt_v1"
          ),
          data: @create_attrs
        )

      assert json_response(conn, 403)["errors"] == %{"detail" => "Forbidden"}
    end
  end

  describe "verify Astarte MQTT V1 credentials" do
    @invalid_client_crt "invalid crt"

    @verify_attrs %{"client_crt" => @client_crt}
    @invalid_request_attrs %{"client_crt" => ""}
    @invalid_crt_attrs %{"client_crt" => @invalid_client_crt}

    setup %{conn: conn, realm_name: realm_name, device: device} do
      update_credentials_secret!(realm_name, device.id, @secret)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@secret}")
        |> put_resp_header("accept", "application/json")

      {:ok, conn: conn}
    end

    test "renders credentials status when data is valid", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      conn =
        post(
          conn,
          device_path(
            conn,
            :verify_credentials,
            realm_name,
            device.encoded_id,
            "astarte_mqtt_v1"
          ),
          data: @verify_attrs
        )

      assert %{"valid" => true, "timestamp" => timestamp, "until" => until} =
               json_response(conn, 200)["data"]

      assert {:ok, _timestamp_dt, 0} = DateTime.from_iso8601(timestamp)
      assert {:ok, _until_dt, 0} = DateTime.from_iso8601(until)
    end

    test "renders errors when request is invalid", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      conn =
        post(
          conn,
          device_path(
            conn,
            :verify_credentials,
            realm_name,
            device.encoded_id,
            "astarte_mqtt_v1"
          ),
          data: @invalid_request_attrs
        )

      assert json_response(conn, 422)["errors"] == %{"client_crt" => ["can't be blank"]}
    end

    test "renders errors when credentials are invalid", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      conn =
        post(
          conn,
          device_path(
            conn,
            :verify_credentials,
            realm_name,
            device.encoded_id,
            "astarte_mqtt_v1"
          ),
          data: @invalid_crt_attrs
        )

      assert %{
               "valid" => false,
               "timestamp" => _timestamp,
               "cause" => "INVALID",
               "details" => nil
             } = json_response(conn, 200)["data"]
    end

    test "renders forbidden error when realm does not exist", ctx do
      %{conn: conn, device: device} = ctx

      realm_name = "unknown"

      conn =
        post(
          conn,
          device_path(
            conn,
            :verify_credentials,
            realm_name,
            device.encoded_id,
            "astarte_mqtt_v1"
          ),
          data: @verify_attrs
        )

      assert json_response(conn, 403)["errors"] == %{"detail" => "Forbidden"}
    end
  end

  describe "get device info" do
    @version Mix.Project.config()[:version]
    @broker_url "mqtts://broker.beta.astarte.cloud:8883/"

    setup %{conn: conn, realm_name: realm_name, device: device} do
      update_credentials_secret!(realm_name, device.id, @secret)

      conn =
        conn
        |> put_req_header("authorization", "BEARER #{@secret}")
        |> put_resp_header("accept", "application/json")

      {:ok, conn: conn}
    end

    test "renders info status", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      conn = get(conn, device_path(conn, :show_info, realm_name, device.encoded_id))

      assert %{"version" => @version, "status" => status, "protocols" => protocols} =
               json_response(conn, 200)["data"]

      assert status in ["pending", "confirmed", "inhibited"]

      assert %{"astarte_mqtt_v1" => %{"broker_url" => @broker_url}} = protocols
    end

    test "renders info status as inhibited when credentials request is inhibited", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      update_device!(realm_name, device.id, inhibit_credentials_request: true)

      conn = get(conn, device_path(conn, :show_info, realm_name, device.encoded_id))

      assert %{"status" => status} = json_response(conn, 200)["data"]
      assert status == "inhibited"
    end

    test "renders info status as confirmed when device has a first credentials request", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      update_device!(realm_name, device.id,
        inhibit_credentials_request: false,
        first_credentials_request: DateTime.utc_now()
      )

      conn = get(conn, device_path(conn, :show_info, realm_name, device.encoded_id))

      assert %{"status" => status} = json_response(conn, 200)["data"]
      assert status == "confirmed"
    end

    test "renders info status as pending when device doesn't have a first credentials request",
         ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      update_device!(realm_name, device.id,
        inhibit_credentials_request: false,
        first_credentials_request: nil
      )

      conn = get(conn, device_path(conn, :show_info, realm_name, device.encoded_id))

      assert %{"status" => status} = json_response(conn, 200)["data"]
      assert status == "pending"
    end

    test "renders error with invalid secret", ctx do
      %{conn: conn, realm_name: realm_name, device: device} = ctx

      conn = put_req_header(conn, "authorization", "BEARER invalidsecret")

      conn = get(conn, device_path(conn, :show_info, realm_name, device.encoded_id))
      assert json_response(conn, 403)["errors"] == %{"detail" => "Forbidden"}
    end

    test "renders forbidden error when realm does not exist", ctx do
      %{conn: conn, device: device} = ctx

      realm_name = "unknown"

      conn = get(conn, device_path(conn, :show_info, realm_name, device.encoded_id))

      assert json_response(conn, 403)["errors"] == %{"detail" => "Forbidden"}
    end
  end
end
