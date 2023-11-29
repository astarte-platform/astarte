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
    GetAgentPublicKeyPEMs,
    GetAgentPublicKeyPEMsReply,
    GetCredentials,
    GetCredentialsReply,
    GetInfo,
    GetInfoReply,
    IntrospectionEntry,
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
  MIIFXzCCA0egAwIBAgIJAJcfGLwm3CXCMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
  BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
  aWRnaXRzIFB0eSBMdGQwIBcNMTgxMDE5MTU1MzE0WhgPMjExODA5MjUxNTUzMTRa
  MEUxCzAJBgNVBAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJ
  bnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
  ggIKAoICAQCxKV5RebdNpyhpJSboZBAB9mHH79a+xxUwJVkt1GBw/F93cC4gAOL8
  YhaLVCZA9wFuAZnsNrSKWak1l7MCmAvDHqW/jRiy5IPTtI+XN1GQ2IGLD2OOPQkS
  lChirOqRHqrAfUG0mVL9dSQdnpfIgvjtVOSDoygA1wD0e1Ba6arVbsT75Ts/U+oz
  nMT+UtywlHD+WPdVcIqi1Q4yKYooNmqZZX28lDfoVleXZp7kVyVh/g+y1kD53VKe
  hZFY6CD3sEFJ5If4I/6PnhXCo0xsLSAZbCa1WJ+mJDxO57DAmtpOljGOiLtWWITD
  w5AoLSA6xAiKDm+dUD8pyk/Tf1hgtukBLmiqDpARdUTJ7WXDCpEpoGa2UX5i6bk+
  qRUoGCprGz7PLrdoXTabTSyjiCYHFhxJHiBzI5Q95TUjylhkHmIKzjodiu7+S1uV
  Fyc523iKzdbexZPPj7QbiABJkAvpGF7yPDZ1Z3kKovK+fcFfXl7il5DGFq6noMRG
  GqcvLFq+TW+fZgdEbbVDzQn3sEHmiuCIzH4Bsv0XxFJpo6B2wWzS2iC60ul5LtVO
  VWFPDlLnIOnxrCmQ2jVElUyjdn2PmnBA5E+UzKi85KAZGxbdF6hYM4LCQg3csTp4
  Az9RkhZSXhcZn/54006v1uXfW7ommgm0xGnxYTDW5CE30ZATYbbjhQIDAQABo1Aw
  TjAdBgNVHQ4EFgQUl09KTABzn/kpSk8MW4F5GXRqtWMwHwYDVR0jBBgwFoAUl09K
  TABzn/kpSk8MW4F5GXRqtWMwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQsFAAOC
  AgEADNs4H+LBTrlXID4Kf8PFDYpQMfdp+j7tZQn20CLygism9M+6ZTpCcdCDqVc7
  cqEWRN2Nr+gPYW8XRYlIomOrqIpOA1ZXxc6NKFkJuM4fwBX4PyU7Moho/5d4QWr3
  CIQDoqvAmduDQt+1ROTcs1dN+oULoOeGjtVBkEaRi1xbg7pM2ELJPNuKw7YUcaSE
  IhRfCxBQgvF/OzF3fYSclRAWbkGN9/DGnlMtMABB3oDM0hCJh/FQuiVwKLCbUTyh
  YlbKkYGx0acjlMtenAM+0LKXHPLiiGEoxJA1+nxfuq/otHqcAMQCcpI8keI/lv1P
  LLd44jk15b9pbX3oVkc1ZJJ7kH0TWtHU/o9bN5Q/vIn8QsYDr2FVVSPV/0khXABh
  KSqrMuSIMPjcMJFLwchyMGhhKTM3fmSIlH9UFHQgRghFDswXXyvF5lcymV2GKW5/
  /sZJg+d/HZXRHk46+fhn55Vde50Vlh2V7f7Hxu8tns7wQByjsLELn7CFKUvTniFr
  JDRMijrvth8fLisxljPbrpAVLdSpopY0XN+mYa6sfRpyHrdMG8RbcMl/kkMWCtCu
  D0GDR7ujOWB7aerzB9PRS6/3EmQ2YqJOogb2j1roMnEnguvr0CCCwBUNnfWTMZ0c
  MN3cVj1AQtdZcG1Pd7ZbwrNphJOCx4C1PLKWVrkGHe2yBTE=
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

  describe "GetAgentPublicKeyPEMs" do
    test "fails with invalid realm" do
      encoded =
        %Call{call: {:get_agent_public_key_pems, %GetAgentPublicKeyPEMs{realm: "invalid"}}}
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      expected_err_reply = %Reply{
        error: true,
        reply:
          {:generic_error_reply,
           %GenericErrorReply{
             error_name: "realm_not_found",
             error_data: nil,
             user_readable_error_name: nil,
             user_readable_message: nil,
             user_readable_message: nil
           }},
        version: 0
      }

      assert Reply.decode(reply) == expected_err_reply
    end

    test "successful call" do
      encoded =
        %Call{call: {:get_agent_public_key_pems, %GetAgentPublicKeyPEMs{realm: @test_realm}}}
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      pems = DatabaseTestHelper.agent_public_key_pems()

      assert %Reply{
               error: false,
               reply:
                 {:get_agent_public_key_pems_reply,
                  %GetAgentPublicKeyPEMsReply{agent_public_key_pems: ^pems}}
             } = Reply.decode(reply)
    end
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
        reply:
          {:generic_error_reply,
           %GenericErrorReply{
             error_name: "realm_not_found",
             error_data: nil,
             user_readable_error_name: nil,
             user_readable_message: nil,
             user_readable_message: nil
           }},
        version: 0
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
      hw_id = DatabaseTestHelper.registered_and_confirmed_256_hw_id()
      secret = DatabaseTestHelper.registered_and_confirmed_256_credentials_secret()

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
        DatabaseTestHelper.set_device_registration_limit(@test_realm, nil)
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

    test "successful call with initial introspection" do
      initial_introspection = [
        %IntrospectionEntry{
          interface_name: "org.astarteplatform.Values",
          major_version: 0,
          minor_version: 2
        }
      ]

      encoded =
        %Call{
          call:
            {:register_device,
             %RegisterDevice{
               realm: @test_realm,
               hw_id: @test_hw_id_1,
               initial_introspection: initial_introspection
             }}
        }
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
        reply:
          {:generic_error_reply,
           %GenericErrorReply{
             error_name: "invalid_device_id",
             error_data: nil,
             user_readable_error_name: nil,
             user_readable_message: nil
           }},
        version: 0
      }

      assert expected_err_reply == Reply.decode(reply)
    end

    test "fails when device registration limit is reached" do
      DatabaseTestHelper.set_device_registration_limit(@test_realm, 0)
      device_id = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      encoded =
        %Call{call: {:register_device, %RegisterDevice{realm: @test_realm, hw_id: device_id}}}
        |> Call.encode()

      {:ok, reply} = Handler.handle_rpc(encoded)

      expected_err_reply = %Reply{
        error: true,
        reply:
          {:generic_error_reply,
           %GenericErrorReply{
             error_name: "device_registration_limit_reached",
             error_data: nil,
             user_readable_error_name: nil,
             user_readable_message: nil
           }},
        version: 0
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
        reply:
          {:generic_error_reply,
           %GenericErrorReply{
             error_name: "invalid_ip",
             error_data: nil,
             user_readable_error_name: nil,
             user_readable_message: nil
           }},
        version: 0
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

      hw_id = DatabaseTestHelper.registered_and_confirmed_256_hw_id()
      secret = DatabaseTestHelper.registered_and_confirmed_256_credentials_secret()

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
