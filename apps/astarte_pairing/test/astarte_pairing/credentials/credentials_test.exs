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
  @csr_valid_until 1_755_940_320_000
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
  @self_signed_crt """
  -----BEGIN CERTIFICATE-----
  MIIDCTCCAfGgAwIBAgIUCvQSmpjHOp9gqVs5r3C+3Mqf+cAwDQYJKoZIhvcNAQEL
  BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI1MDYyMzE1NTk0MFoXDTI2MDYy
  MzE1NTk0MFowFDESMBAGA1UEAwwJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0BAQEF
  AAOCAQ8AMIIBCgKCAQEAsIUOltZQbKfFHQQYNRXoECMHBXS3AhQg7sRV1dxZJGag
  BRS0Whj8yj/wJ5lX+eb44YnSOk4nShzWsk74wKK+eeVeKPRvDhY+cotXXKNNk7Gj
  ofOYcaULd29WPHJN2trCSeuOQm2IYNjwp2ityjsi+ZUwQzxbvcMFiF6Mfde3K/7n
  ql6rBhavKPkUZexbbW+fla5XgaIMXRWuTVIxZU+hg1WYyFCzpD/jjJe/5Fmy4XNY
  FeJsBJy8cU75FlSFxT+iqHx6HqyliQ7WyTSGY9fQAxA9HIUO2msx7+sxBIHRUvvy
  G7gbMtCrDy2Wtgwv213AKMpnODHkxJ8+oBv8H4GyAQIDAQABo1MwUTAdBgNVHQ4E
  FgQULGyzs0yVMCBUbvCNYcBLjngrErEwHwYDVR0jBBgwFoAULGyzs0yVMCBUbvCN
  YcBLjngrErEwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAXp35
  ahNY2sRbR1JYednnN+hj8r4IhrDMKB6ZWP03M1OWTJ1Z/6NXkmBQkGxAGxP5cpyJ
  IeMVb0oNdahUbILCPBAkMyP8ZbFnyLaUjbFT1yH1tzaFmmsx72IJZ4fo2ONBZgxL
  +2B25D7o237wVBcrik8Gm2X64GZzx58JJnSI7JrS4jC6iTJn/s88M+losXpzSSHM
  ZvcUXC5itRNckAeiMiyx4F+dOnhvAsfbq/rj5SLjtXgEFDLRg9yRpaIAnFKPTPqH
  nVi/3xx9CJUmQLgi87mvZct/5gCchtWYD+aYgOSPhyXxW1eNT7tHUgKFgj0jRdOw
  HGLVqURVzFzEHx1vgQ==
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
