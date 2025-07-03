#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.EngineTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  alias Astarte.Core.Device
  alias Astarte.Pairing.CredentialsSecret
  alias Astarte.Helpers.Database, as: DatabaseTestHelper
  alias Astarte.Pairing.Engine
  alias Astarte.Pairing.Queries
  alias CFXXL.CertUtils
  alias Astarte.DataAccess.Realms.Realm

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

  @astarte_protocol :astarte_mqtt_v1
  @astarte_credentials_params %{csr: @test_csr}

  @valid_ip "2.3.4.5"

  describe "get_agent_public_key_pem" do
    test "fails with non-existing realm" do
      realm_keyspace = Realm.keyspace_name("nonexisting")

      assert_raise Xandra.Error, "Keyspace #{realm_keyspace} does not exist", fn ->
        Engine.get_agent_public_key_pems("nonexisting")
      end
    end

    test "successful call", %{realm: realm} do
      pems = Application.get_env(:astarte_pairing, :jwt_public_key_pem)

      assert {:ok, [^pems]} = Engine.get_agent_public_key_pems(realm)
    end
  end

  describe "register_device" do
    test "fails with non-existing realm" do
      hw_id = DatabaseTestHelper.random_128_bit_hw_id()
      realm = "nonexisting"

      assert {:error, :realm_not_found} = Engine.register_device(realm, hw_id)
    end

    test "fails with invalid hw_id",
         %{
           realm: realm
         } do
      hw_id = "invalid"

      assert {:error, :invalid_device_id} = Engine.register_device(realm, hw_id)
    end

    test "fails with registered and confirmed device",
         %{
           realm: realm,
           confirmed_device: %{encoded_id: device_id}
         } do
      Engine.register_device(realm, device_id)

      assert {:error, :device_already_registered} =
               Engine.register_device(realm, device_id)
    end

    test "succeeds and generates new credentials_secret with registered and not confirmed device",
         %{
           realm: realm,
           unconfirmed_device: %{encoded_id: device_id}
         } do
      first_registration = DatabaseTestHelper.get_first_registration(realm, device_id)
      assert first_registration != nil

      assert {:ok, credentials_secret} = Engine.register_device(realm, device_id)

      assert credentials_secret !=
               DatabaseTestHelper.registered_not_confirmed_credentials_secret()

      assert DatabaseTestHelper.get_first_registration(realm, device_id) == first_registration
    end

    test "succeed and saves the introspection with initial_introspection", %{
      realm: realm,
      unconfirmed_device: %{encoded_id: device_id}
    } do
      initial_introspection = [
        %{
          interface_name: "org.astarteplatform.Values",
          major_version: 0,
          minor_version: 3
        },
        %{
          interface_name: "org.astarteplatform.OtherValues",
          major_version: 1,
          minor_version: 2
        }
      ]

      assert {:ok, _credentials_secret} =
               Engine.register_device(realm, device_id,
                 initial_introspection: initial_introspection
               )

      introspection = DatabaseTestHelper.get_introspection(realm, device_id)
      introspection_minor = DatabaseTestHelper.get_introspection_minor(realm, device_id)

      assert Enum.member?(introspection, {"org.astarteplatform.Values", 0})
      assert Enum.member?(introspection_minor, {"org.astarteplatform.Values", 3})

      assert Enum.member?(introspection, {"org.astarteplatform.OtherValues", 1})
      assert Enum.member?(introspection_minor, {"org.astarteplatform.OtherValues", 2})
    end

    test "fails when device_registration_limit is reached", %{
      realm: realm,
      confirmed_device: %{encoded_id: hw_id, first_registration: first_registration}
    } do
      DatabaseTestHelper.set_device_registration_limit(realm, 1)

      assert DatabaseTestHelper.get_first_registration(realm, hw_id)
             |> DateTime.to_unix(:millisecond) == first_registration

      unregistered_hw_id = DatabaseTestHelper.random_128_bit_hw_id()

      assert {:error, :device_registration_limit_reached} =
               Engine.register_device(realm, unregistered_hw_id)
    end

    test "does not reset received message count with registered and not confirmed device", %{
      realm: realm,
      unregistered_device: %{encoded_id: hw_id}
    } do
      total_received_msgs = System.unique_integer([:positive])
      total_received_bytes = System.unique_integer([:positive])

      DatabaseTestHelper.set_received_message_count_for_device(
        realm,
        hw_id,
        total_received_msgs,
        total_received_bytes
      )

      assert {:ok, _new_credentials_secret} = Engine.register_device(realm, hw_id)

      assert [
               %{
                 total_received_msgs: ^total_received_msgs,
                 total_received_bytes: ^total_received_bytes
               }
             ] = DatabaseTestHelper.get_message_count_for_device(realm, hw_id)
    end

    test "succeeds when re-registering an existing device after device_registration_limit is reached",
         %{
           realm: realm
         } do
      DatabaseTestHelper.set_device_registration_limit(realm, 7)
      hw_id = DatabaseTestHelper.random_128_bit_hw_id()
      {:ok, _credentials_secret} = Engine.register_device(realm, hw_id)
      :ok = Engine.unregister_device(realm, hw_id)

      assert {:ok, _credentials_secret} = Engine.register_device(realm, hw_id)
    end
  end

  describe "unregister device" do
    test "fails with non-existing realm", %{
      device: %{encoded_id: device_id}
    } do
      realm_keyspace = Realm.keyspace_name("nonexisting")

      assert_raise Xandra.Error, "Keyspace #{realm_keyspace} does not exist", fn ->
        Engine.unregister_device("nonexisting", device_id)
      end
    end

    test "fails with invalid device_id", %{
      realm: realm
    } do
      assert {:error, :invalid_device_id} = Engine.unregister_device(realm, "invalid")
    end

    test "fails with never registered device_id", %{
      realm: realm
    } do
      device_id = DatabaseTestHelper.random_128_bit_hw_id()
      assert {:error, :device_not_found} = Engine.unregister_device(realm, device_id)
    end

    test "succeeds with registered and confirmed device_id, and makes it possible to register it again",
         %{device: %{encoded_id: device_id}, realm: realm} do
      assert :ok = Engine.unregister_device(realm, device_id)

      assert {:ok, _credentials_secret} = Engine.register_device(realm, device_id)
    end

    test "succeeds when unregistering the same device multiple times",
         %{device: %{encoded_id: device_id}, realm: realm} do
      assert :ok = Engine.unregister_device(realm, device_id)

      assert :ok = Engine.unregister_device(realm, device_id)
    end
  end

  describe "get_credentials" do
    test "fails with invalid secret",
         %{device: %{encoded_id: hw_id}, realm: realm} do
      secret = CredentialsSecret.generate()

      assert {:error, :forbidden} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 realm,
                 hw_id,
                 secret,
                 @valid_ip
               )
    end

    test "fails with invalid protocol", %{device: %{encoded_id: hw_id}, realm: realm} do
      secret = CredentialsSecret.generate()

      assert {:error, :unknown_protocol} =
               Engine.get_credentials(
                 :other_protocol,
                 %{other: "params"},
                 realm,
                 hw_id,
                 secret,
                 @valid_ip
               )
    end

    test "fails with invalid IP", %{device: %{encoded_id: hw_id}, realm: realm} do
      invalid_ip = "300.21.251.3"

      secret = DatabaseTestHelper.registered_and_confirmed_256_credentials_secret()

      assert {:error, :invalid_ip} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 realm,
                 hw_id,
                 secret,
                 invalid_ip
               )
    end

    test "fails with unexisting realm", %{device: %{encoded_id: hw_id}} do
      realm_keyspace = Realm.keyspace_name("unexisting")
      secret = DatabaseTestHelper.registered_and_confirmed_256_credentials_secret()

      assert_raise Xandra.Error, "Keyspace #{realm_keyspace} does not exist", fn ->
        Engine.get_credentials(
          @astarte_protocol,
          @astarte_credentials_params,
          "unexisting",
          hw_id,
          secret,
          @valid_ip
        )
      end
    end

    test "fails with not registered device", %{realm: realm} do
      secret = CredentialsSecret.generate()
      hw_id = DatabaseTestHelper.random_128_bit_hw_id()

      assert {:error, :device_not_found} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 realm,
                 hw_id,
                 secret,
                 @valid_ip
               )
    end

    test "fails with inhibited device", %{
      inhibited_device: %{encoded_id: hw_id, credentials_secret: secret},
      realm: realm
    } do
      assert {:error, :credentials_request_inhibited} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 realm,
                 hw_id,
                 secret,
                 @valid_ip
               )
    end

    test "revokes the crt if repeated", %{
      confirmed_device: %{encoded_id: hw_id, credentials_secret: secret},
      realm: realm
    } do
      assert {:ok, %{client_crt: _first_certificate}} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 realm,
                 hw_id,
                 secret,
                 @valid_ip
               )

      assert {:ok, %{client_crt: second_certificate}} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 realm,
                 hw_id,
                 secret,
                 @valid_ip
               )

      second_aki = CertUtils.authority_key_identifier!(second_certificate)
      second_serial = CertUtils.serial_number!(second_certificate)

      {:ok, device_id} = Device.decode_device_id(hw_id, allow_extended_id: true)

      {:ok, device} = Queries.fetch_device(realm, device_id)

      assert device.cert_aki == second_aki
      assert device.cert_serial == second_serial
    end
  end
end
