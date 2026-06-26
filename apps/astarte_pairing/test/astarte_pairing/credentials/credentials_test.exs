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

defmodule Astarte.Pairing.CredentialsTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device

  import Astarte.Helpers.Device

  alias Astarte.Pairing.Credentials

  @device_ip "2.3.4.5"
  @secret "valid"
  @invalid_secret "invalid"
  @unexisting_realm "unexisting"
  @unexisting_hw_id "G5rDPSk1SOKuErbBnk2rhw"

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
  # valid until 16 September 2035 16:02:06
  @csr_valid_until 2_073_571_326_000
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

  # CRT valid until June 23, 2036
  @self_signed_crt """
  -----BEGIN CERTIFICATE-----
  MIIC8jCCAdqgAwIBAgIGAZ8EWdyBMA0GCSqGSIb3DQEBCwUAMDoxEjAQBgNVBAMMCW
  xvY2FsaG9zdDEkMCIGCSqGSIb3DQEJARYVbm8tcmVwbHlAc2Vjb21pbmQuY29tMB4X
  DTI2MDYyNjE0MzM0NVoXDTM2MDYyMzE0MzM0NVowOjESMBAGA1UEAwwJbG9jYWxob3
  N0MSQwIgYJKoZIhvcNAQkBFhVuby1yZXBseUBzZWNvbWluZC5jb20wggEiMA0GCSqG
  SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDbxaP7uDcJUbZZBrEDsmroRsWYvpQQ8Sx07a
  Hy6C14uMPbvxJxE2t354rLZgJPBgNyOzlGqtjnfvonNSHqTGTOgko7eAGrXnvklTMw
  nxy4kdwTipsHm9Zjt6thB2eIXZzwCOUCDL8z3N2FniXEmpHbPHrvpMw2CddDTTA/ss
  TYJywMm5Y8PC+qszJL7xxY9zvPHET7aZ/299hZOJzO3wFXwE644baoNZgeDkz/zZVQ
  ejANJWOQv6aGTb/z89pvRyu9mKtk3Pf+je85A6CptpoH8ErOPNnm9PFJGq11Orn/Lp
  JIbm0WlUbwNqyrD452hZ19L3Knj9IyKWH4LC15C01rAgMBAAEwDQYJKoZIhvcNAQEL
  BQADggEBAHxw6bAN41cD84vVZi/1/JwhiQodQFUb0o3JylBjeuozOy86rfgtTNndrt
  v1sMcv62fw0rhz05DAnxztlrMnEydh5yda94r3aqj1xVA1TkeQ5GGzWiSohYgVMj/l
  7zi8tdokG1S4bTdsz2FEbvWnLPD6yDQsUOK13vhD3iv5ruPpAdyi7ZkWiU+uskOWnP
  dF399B44BViJa9rq3czEl/9V/u7t+nwErHZVlluSC3jKOwq2fnrm7GFwElp43AJgxv
  2pr6QNrmpdsGMX+juH1MSpz+6SmfXP5H+vj4Nf4J6t621IQLRQ/tzQZ7NqKKsbNiTS
  6ldXWCOPhWRJxD/qrPbwk=
  -----END CERTIFICATE-----
  """

  setup [:set_credentials_secret, :set_ca_cert]

  def set_credentials_secret(ctx) do
    update_device!(ctx.realm_name, ctx.device.id, inhibit_credentials_request: false)
    update_credentials_secret!(ctx.realm_name, ctx.device.id, @secret)

    :ok
  end

  defp set_ca_cert(_ctx) do
    Mimic.stub(Astarte.Pairing.Config, :ca_cert!, fn -> @ca_cert end)

    :ok
  end

  describe "get_astarte_mqtt_v1" do
    alias Astarte.Pairing.Credentials.AstarteMQTTV1.Credentials, as: AstarteCredentials

    @valid_attrs %{"csr" => @csr}
    @no_csr_attrs %{}
    @invalid_csr_attrs %{"csr" => "invalidcsr"}

    test "returns Credentials with valid data", ctx do
      %{
        realm_name: realm_name,
        device: device
      } = ctx

      assert {:ok, %AstarteCredentials{client_crt: client_crt}} =
               Credentials.get_astarte_mqtt_v1(
                 realm_name,
                 device.encoded_id,
                 @secret,
                 @device_ip,
                 @valid_attrs
               )

      assert client_crt =~ "-----BEGIN CERTIFICATE-----"
    end

    test "returns error changeset with malformed data", ctx do
      %{realm_name: realm_name, device: device} = ctx

      assert {:error, %Ecto.Changeset{}} =
               Credentials.get_astarte_mqtt_v1(
                 realm_name,
                 device.encoded_id,
                 @secret,
                 @device_ip,
                 @no_csr_attrs
               )

      assert {:error, %Ecto.Changeset{}} =
               Credentials.get_astarte_mqtt_v1(
                 realm_name,
                 device.encoded_id,
                 @secret,
                 @device_ip,
                 @invalid_csr_attrs
               )
    end

    test "returns forbidden with invalid secret", ctx do
      %{
        realm_name: realm_name,
        device: device
      } = ctx

      assert {:error, :forbidden} =
               Credentials.get_astarte_mqtt_v1(
                 realm_name,
                 device.encoded_id,
                 @invalid_secret,
                 @device_ip,
                 @valid_attrs
               )
    end

    test "raises with realm not found", ctx do
      assert_raise Xandra.Error, ~r"Keyspace .*#{@unexisting_realm} does not exist", fn ->
        Credentials.get_astarte_mqtt_v1(
          @unexisting_realm,
          ctx.device.encoded_id,
          @secret,
          @device_ip,
          @valid_attrs
        )
      end
    end

    test "returns device_not_found with device not found", ctx do
      %{
        realm_name: realm_name
      } = ctx

      assert {:error, :device_not_found} =
               Credentials.get_astarte_mqtt_v1(
                 realm_name,
                 @unexisting_hw_id,
                 @secret,
                 @device_ip,
                 @valid_attrs
               )
    end
  end

  describe "verify_astarte_mqtt_v1" do
    alias Astarte.Pairing.Credentials.AstarteMQTTV1.CredentialsStatus

    @valid_attrs %{client_crt: @client_crt}
    @no_certificate_attrs %{}
    @self_signed_crt_attrs %{client_crt: @self_signed_crt}

    test "valid call returns CredentialsStatus", ctx do
      %{
        realm_name: realm_name,
        device: device
      } = ctx

      assert {:ok,
              %CredentialsStatus{
                valid: true,
                until: one_month_from_now,
                timestamp: _now,
                cause: nil,
                details: nil
              }} =
               Credentials.verify_astarte_mqtt_v1(
                 realm_name,
                 device.encoded_id,
                 @secret,
                 @valid_attrs
               )

      assert one_month_from_now == @csr_valid_until
    end

    test "returns an error changeset with invalid attrs", ctx do
      %{
        realm_name: realm_name,
        device: device
      } = ctx

      assert {:error, %Ecto.Changeset{}} =
               Credentials.verify_astarte_mqtt_v1(
                 realm_name,
                 device.encoded_id,
                 @secret,
                 @no_certificate_attrs
               )
    end

    test "returns invalid CertificateStatus", ctx do
      %{
        realm_name: realm_name,
        device: device
      } = ctx

      assert {:ok,
              %CredentialsStatus{
                valid: false,
                timestamp: _timestamp,
                cause: :INVALID_ISSUER,
                until: nil,
                details: nil
              }} =
               Credentials.verify_astarte_mqtt_v1(
                 realm_name,
                 device.encoded_id,
                 @secret,
                 @self_signed_crt_attrs
               )
    end

    test "returns invalid CertificateStatus for empty-details branch", ctx do
      %{
        realm_name: realm_name,
        device: device
      } = ctx

      assert {:ok,
              %CredentialsStatus{
                valid: false,
                timestamp: _timestamp,
                cause: :INVALID_ISSUER,
                details: nil,
                until: nil
              }} =
               Credentials.verify_astarte_mqtt_v1(
                 realm_name,
                 device.encoded_id,
                 @secret,
                 @self_signed_crt_attrs
               )
    end

    test "returns forbidden with invalid secret", %{realm_name: realm_name, device: device} do
      assert {:error, :forbidden} =
               Credentials.verify_astarte_mqtt_v1(
                 realm_name,
                 device.encoded_id,
                 @invalid_secret,
                 @valid_attrs
               )
    end

    test "raises with realm not found", ctx do
      assert_raise Xandra.Error, ~r"Keyspace .*#{@unexisting_realm} does not exist", fn ->
        Credentials.verify_astarte_mqtt_v1(
          @unexisting_realm,
          ctx.device.encoded_id,
          @secret,
          @valid_attrs
        )
      end
    end

    test "returns device_not_found with device not found", %{realm_name: realm_name} do
      assert {:error, :device_not_found} =
               Credentials.verify_astarte_mqtt_v1(
                 realm_name,
                 @unexisting_hw_id,
                 @secret,
                 @valid_attrs
               )
    end
  end
end
