#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.Pairing.API.CredentialsTest do
  use Astarte.Pairing.API.DataCase

  alias Astarte.Pairing.API.Credentials

  alias Astarte.RPC.Protocol.Pairing.{
    AstarteMQTTV1Credentials,
    AstarteMQTTV1CredentialsParameters,
    AstarteMQTTV1CredentialsStatus,
    Call,
    GenericErrorReply,
    GetCredentials,
    GetCredentialsReply,
    Reply,
    VerifyCredentials,
    VerifyCredentialsReply
  }

  import Mox

  @realm "test_realm"
  @hw_id "ykwVk4uTT_SQMe-4Opn-qg"
  @device_ip "2.3.4.5"
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
  @secret "valid"
  @client_crt """
  THIS IS NOT A REAL CERTIFICATE
  """

  @unexisting_realm "unexisting"
  @unexisting_hw_id "G5rDPSk1SOKuErbBnk2rhw"
  @invalid_secret "invalid"
  @self_signed_crt "self signed crt"

  @encoded_forbidden_response %Reply{
                                reply:
                                  {:generic_error_reply,
                                   %GenericErrorReply{error_name: "forbidden"}}
                              }
                              |> Reply.encode()

  @encoded_realm_not_found_response %Reply{
                                      reply:
                                        {:generic_error_reply,
                                         %GenericErrorReply{error_name: "realm_not_found"}}
                                    }
                                    |> Reply.encode()

  @encoded_device_not_found_response %Reply{
                                       reply:
                                         {:generic_error_reply,
                                          %GenericErrorReply{error_name: "device_not_found"}}
                                     }
                                     |> Reply.encode()

  @rpc_destination Astarte.RPC.Protocol.Pairing.amqp_queue()
  @timeout 30_000

  describe "get_astarte_mqtt_v1" do
    alias Astarte.Pairing.API.Credentials.AstarteMQTTV1.Credentials, as: AstarteCredentials

    @valid_attrs %{"csr" => @csr}
    @no_csr_attrs %{}
    @invalid_csr_attrs %{"csr" => "invalidcsr"}

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

    test "returns Credentials with valid data" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:get_credentials, %GetCredentials{} = credentials_call}} =
                 Call.decode(serialized_call)

        assert %GetCredentials{
                 realm: @realm,
                 hw_id: @hw_id,
                 secret: @secret,
                 credentials_parameters:
                   {:astarte_mqtt_v1, %AstarteMQTTV1CredentialsParameters{csr: @csr}}
               } = credentials_call

        {:ok, @encoded_credentials_response}
      end)

      assert {:ok, %AstarteCredentials{client_crt: @client_crt}} =
               Credentials.get_astarte_mqtt_v1(
                 @realm,
                 @hw_id,
                 @secret,
                 @device_ip,
                 @valid_attrs
               )
    end

    test "returns error changeset with malformed data" do
      assert {:error, %Ecto.Changeset{}} =
               Credentials.get_astarte_mqtt_v1(
                 @realm,
                 @hw_id,
                 @secret,
                 @device_ip,
                 @no_csr_attrs
               )

      assert {:error, %Ecto.Changeset{}} =
               Credentials.get_astarte_mqtt_v1(
                 @realm,
                 @hw_id,
                 @secret,
                 @device_ip,
                 @invalid_csr_attrs
               )
    end

    test "returns forbidden with invalid secret" do
      MockRPCClient
      |> expect(:rpc_call, fn _serialized_call, @rpc_destination, @timeout ->
        {:ok, @encoded_forbidden_response}
      end)

      assert {:error, :forbidden} =
               Credentials.get_astarte_mqtt_v1(
                 @realm,
                 @hw_id,
                 @invalid_secret,
                 @device_ip,
                 @valid_attrs
               )
    end

    test "returns forbidden with realm not found" do
      MockRPCClient
      |> expect(:rpc_call, fn _serialized_call, @rpc_destination, @timeout ->
        {:ok, @encoded_realm_not_found_response}
      end)

      assert {:error, :forbidden} =
               Credentials.get_astarte_mqtt_v1(
                 @unexisting_realm,
                 @hw_id,
                 @secret,
                 @device_ip,
                 @valid_attrs
               )
    end

    test "returns device_not_found with device not found" do
      MockRPCClient
      |> expect(:rpc_call, fn _serialized_call, @rpc_destination, @timeout ->
        {:ok, @encoded_device_not_found_response}
      end)

      assert {:error, :device_not_found} =
               Credentials.get_astarte_mqtt_v1(
                 @realm,
                 @unexisting_hw_id,
                 @secret,
                 @device_ip,
                 @valid_attrs
               )
    end
  end

  describe "verify_astarte_mqtt_v1" do
    alias Astarte.Pairing.API.Credentials.AstarteMQTTV1.CredentialsStatus

    @valid_attrs %{client_crt: @client_crt}
    @no_certificate_attrs %{}
    @self_signed_crt_attrs %{client_crt: @self_signed_crt}

    @now DateTime.utc_now() |> DateTime.to_unix(:millisecond)
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
                                                   cause: :INVALID_ISSUER
                                                 }}
                                            }}
                                       }
                                       |> Reply.encode()

    test "valid call returns CredentialsStatus" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:verify_credentials, %VerifyCredentials{} = verify_credentials_call}} =
                 Call.decode(serialized_call)

        assert %VerifyCredentials{
                 realm: @realm,
                 hw_id: @hw_id,
                 secret: @secret,
                 credentials:
                   {:astarte_mqtt_v1, %AstarteMQTTV1Credentials{client_crt: @client_crt}}
               } = verify_credentials_call

        {:ok, @encoded_verify_valid_response}
      end)

      assert {:ok,
              %CredentialsStatus{
                valid: true,
                until: @one_month_from_now,
                timestamp: @now,
                cause: nil,
                details: nil
              }} = Credentials.verify_astarte_mqtt_v1(@realm, @hw_id, @secret, @valid_attrs)
    end

    test "returns an error changeset with invalid attrs" do
      assert {:error, %Ecto.Changeset{}} =
               Credentials.verify_astarte_mqtt_v1(@realm, @hw_id, @secret, @no_certificate_attrs)
    end

    test "returns invalid CertificateStatus" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:verify_credentials, %VerifyCredentials{} = verify_credentials_call}} =
                 Call.decode(serialized_call)

        assert %VerifyCredentials{
                 realm: @realm,
                 hw_id: @hw_id,
                 secret: @secret,
                 credentials:
                   {:astarte_mqtt_v1, %AstarteMQTTV1Credentials{client_crt: @self_signed_crt}}
               } = verify_credentials_call

        {:ok, @encoded_verify_not_valid_response}
      end)

      assert {:ok,
              %CredentialsStatus{
                valid: false,
                timestamp: @now,
                cause: :INVALID_ISSUER,
                until: nil,
                details: nil
              }} =
               Credentials.verify_astarte_mqtt_v1(@realm, @hw_id, @secret, @self_signed_crt_attrs)
    end

    test "returns forbidden with invalid secret" do
      MockRPCClient
      |> expect(:rpc_call, fn _serialized_call, @rpc_destination, @timeout ->
        {:ok, @encoded_forbidden_response}
      end)

      assert {:error, :forbidden} =
               Credentials.verify_astarte_mqtt_v1(
                 @realm,
                 @hw_id,
                 @invalid_secret,
                 @valid_attrs
               )
    end

    test "returns forbidden with realm not found" do
      MockRPCClient
      |> expect(:rpc_call, fn _serialized_call, @rpc_destination, @timeout ->
        {:ok, @encoded_realm_not_found_response}
      end)

      assert {:error, :forbidden} =
               Credentials.verify_astarte_mqtt_v1(
                 @unexisting_realm,
                 @hw_id,
                 @secret,
                 @valid_attrs
               )
    end

    test "returns device_not_found with device not found" do
      MockRPCClient
      |> expect(:rpc_call, fn _serialized_call, @rpc_destination, @timeout ->
        {:ok, @encoded_device_not_found_response}
      end)

      assert {:error, :device_not_found} =
               Credentials.verify_astarte_mqtt_v1(
                 @realm,
                 @unexisting_hw_id,
                 @secret,
                 @valid_attrs
               )
    end
  end
end
