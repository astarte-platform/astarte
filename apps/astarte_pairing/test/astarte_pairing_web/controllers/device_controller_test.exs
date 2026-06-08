#
# This file is part of Astarte.
#
# Copyright 2017 - 2026 SECO Mind Srl
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
  use Astarte.Cases.Conn, async: true

  import Astarte.Helpers.Device

  @secret "supersecret"

  @ca_cert """
  -----BEGIN CERTIFICATE-----
  MIIDazCCAlOgAwIBAgIUQjHvJXmUALMWF3VCJjPLbsw+n/8wDQYJKoZIhvcNAQEL
  BQAwRTELMAkGA1UEBhMCQVUxEzARBgNVBAgMClNvbWUtU3RhdGUxITAfBgNVBAoM
  GEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDAeFw0yNTA5MTgxNTU2MzFaFw0zNTA5
  MTYxNTU2MzFaMEUxCzAJBgNVBAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEw
  HwYDVQQKDBhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQwggEiMA0GCSqGSIb3DQEB
  AQUAA4IBDwAwggEKAoIBAQDaVvxbt6w34VdmSPlnAPN7EAGp8VJv0oXA4z9xd1Pa
  UCPuyAqP2BgXY9dT6+PxzKkBTBVa8fvP4oVjMtCOF+inoofSZHGuJO80dOr9Clb3
  QR2l8e3ATpkNGzj4QaYxFDV2UhPfj2queZi5pX+VAsk1QGpZAoUGembFODP+i5dZ
  FgurfVMp8JEh2njLvFGvZzTPI5nbgAOiaWgcs19KzQeunhvyiMVbgBSwrtLGoNrL
  OKgZLycRooIGDhkHgfy0EH5j/4Gg2sJAWMCPs2SLTi0RnpAcF+zUKW8v4LLQEVE+
  Q3p4oOFlRUpp+84DB6abDOISkxAHHqi2DdCqENNLuP5zAgMBAAGjUzBRMB0GA1Ud
  DgQWBBTc0qN3YTVkXopcf1a3242bqzLXdjAfBgNVHSMEGDAWgBTc0qN3YTVkXopc
  f1a3242bqzLXdjAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQCb
  xtWhCAfgV9MdDITLCpPrmPlOaCSaI7rgOxpoODCy2p63rsRt1SIhGss3b7VNzW5L
  ysqXyEsqYYKj2QEAwQ7Ldwy3Q1EIsjXCnXrTTWdvGs/c2CnJlYL724XnXel4vrbG
  XKocPYvdV/NzpY1T+MJST3mpQ/stN4OaEOQadu7cSB6SdTT6LE+E3FmOZxY/wI57
  WTbQ64RaWm6cAXA4VQcdwquMNLIQ8jsXRc/Xm0T1ISEx49Nk8rcUzw7O2IDa00Nc
  adSylqEO31fyKGP2pIiZADtylxW3ybkdQ470hImkJtMszHW4O/yl9goNO2TLofQI
  hEFCAcrleJbdUbAwhYut
  -----END CERTIFICATE-----
  """
  @csr """
  -----BEGIN CERTIFICATE REQUEST-----
   MIICijCCAXICAQAwRTELMAkGA1UEBhMCQVUxEzARBgNVBAgMClNvbWUtU3RhdGUx
  ITAfBgNVBAoMGEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDCCASIwDQYJKoZIhvcN
  AQEBBQADggEPADCCAQoCggEBAKwr1LhhCG3JTPIt+4ZeRxgTiY0Zuh2cm1o+7O7Y
  Tdj98exqx5de/dEbgZcQZxrkTRfDJgToZQ+6hECH/jOq5NvoY9E3lZKUaFuJNjeQ
  raPWZYhvTDGQmoazlVTwjQP5MoPAxJAOPiG7DO9ocUEbwx6a0V6oqQHObK+zK4wI
  3YWZpexeg0l0B/ZXVRctDw6XLZGOHvBjDrBmY6AK1mbetF+c4MEQxQ0fnDjdFvtr
  iuRRNAvd3QKgAjYHujgzW30Lavb2oCFXTDhew7GFBLkHe6WhMwG9mEvAkRpqPsIO
  mhH/mw+oGbOcj4iQJ5bgVGRCi4JZzzsV/Gb23wyD/124uVECAwEAAaAAMA0GCSqG
  SIb3DQEBCwUAA4IBAQBBfa5NEqhcm7ejN1q5xvJw5T1WLeFW2B4yuLeMvw3PyLiJ
  6bsRtZn3gc+lbzuNW1TOvrxTqyx1nNHsFdkCdZBStGmP4DQQ2fAXobejLb0CYq5J
  /cNZdjnh+8SZI047x4u5NdpZOAAq3qI8dE5w3bw29LTQwGbfP6Qw1mor/iJ6JwOD
  JTdfNzZkGCLFQSQqyQzb8eYcV+qmKVMEN4xKClG8VoYPWgUqz5QlI+j2O1Hdffoe
  wJvFUdkJfKjiEYTGx8xFSf1KrR+DQxLKuLChNCeyL1TfTIFscUh4HFr50R1/L8j8
  Em1TFZhRyNMRR0udWk9cpEBqNs18xjqsBfqs529h
  -----END CERTIFICATE REQUEST-----
  """
  @client_crt """
  -----BEGIN CERTIFICATE-----
   MIIDWjCCAkKgAwIBAgIUHBgMdvTtt+yzvADipcF1uQZWyXQwDQYJKoZIhvcNAQEL
  BQAwRTELMAkGA1UEBhMCQVUxEzARBgNVBAgMClNvbWUtU3RhdGUxITAfBgNVBAoM
  GEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDAeFw0yNTA5MTgxNjAyMDZaFw0zNTA5
  MTYxNjAyMDZaMEUxCzAJBgNVBAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEw
  HwYDVQQKDBhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQwggEiMA0GCSqGSIb3DQEB
  AQUAA4IBDwAwggEKAoIBAQCsK9S4YQhtyUzyLfuGXkcYE4mNGbodnJtaPuzu2E3Y
  /fHsaseXXv3RG4GXEGca5E0XwyYE6GUPuoRAh/4zquTb6GPRN5WSlGhbiTY3kK2j
  1mWIb0wxkJqGs5VU8I0D+TKDwMSQDj4huwzvaHFBG8MemtFeqKkBzmyvsyuMCN2F
  maXsXoNJdAf2V1UXLQ8Oly2Rjh7wYw6wZmOgCtZm3rRfnODBEMUNH5w43Rb7a4rk
  UTQL3d0CoAI2B7o4M1t9C2r29qAhV0w4XsOxhQS5B3uloTMBvZhLwJEaaj7CDpoR
  /5sPqBmznI+IkCeW4FRkQouCWc87Ffxm9t8Mg/9duLlRAgMBAAGjQjBAMB0GA1Ud
  DgQWBBTzoyy+Qqfud8B+lYVyftwzRG0v8zAfBgNVHSMEGDAWgBTc0qN3YTVkXopc
  f1a3242bqzLXdjANBgkqhkiG9w0BAQsFAAOCAQEALQ6GlV8LC6dS5Z9MQvI6N2sJ
  f3/E8lpJQPa++1kNVQKK9UiWReysL4ncEfqFRUUB/HF+3ly+ed9kHqYv5WfjNc1e
  Gs2OF2yh/BetyFgiyU6fo+0BJTSGGZH4vIrfHLE08edyQRCUdtqQyGPE2DNqXVUH
  jyNF+bcRuCk+J5cbHCQAnNdG2c1/462vvYgdudkoIRXFDatBZLdF2A3kOYIapHDx
  DeKiSWNTZ3+HfktpkeUzpLb8D0OJji6uGzT1I6VzYZ6vSCBQgusTIROSbfD0KstT
  eegNnCzcQa54h+misTo0mXX1rcsI0vZG4dwabZKPr2rIlzwn9JxM3hmIjZWmrA==
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
