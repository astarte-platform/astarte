#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.Pairing.EngineTest do
  use ExUnit.Case

  alias Astarte.Core.Device
  alias Astarte.Pairing.Config
  alias Astarte.Pairing.CredentialsSecret
  alias Astarte.Pairing.DatabaseTestHelper
  alias Astarte.Pairing.Engine
  alias Astarte.Pairing.Queries
  alias Astarte.Pairing.TestHelper
  alias CFXXL.CertUtils

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
  @astarte_protocol :astarte_mqtt_v1
  @astarte_credentials_params %{csr: @test_csr}

  @valid_ip "2.3.4.5"

  setup_all do
    DatabaseTestHelper.create_db()

    on_exit(fn ->
      DatabaseTestHelper.drop_db()
    end)
  end

  describe "get_agent_public_key_pem" do
    test "fails with non-existing realm" do
      assert {:error, :realm_not_found} = Engine.get_agent_public_key_pems("nonexisting")
    end

    test "successful call" do
      pems = DatabaseTestHelper.agent_public_key_pems()

      assert {:ok, ^pems} = Engine.get_agent_public_key_pems(@test_realm)
    end
  end

  describe "register_device" do
    setup [:seed_devices]

    test "fails with non-existing realm" do
      hw_id = TestHelper.random_128_bit_hw_id()
      realm = "nonexisting"

      assert {:error, :realm_not_found} = Engine.register_device(realm, hw_id)
    end

    test "fails with invalid hw_id" do
      hw_id = "invalid"

      assert {:error, :invalid_device_id} = Engine.register_device(@test_realm, hw_id)
    end

    test "fails with registered and confirmed device" do
      hw_id = DatabaseTestHelper.registered_and_confirmed_256_hw_id()

      assert {:error, :already_registered} = Engine.register_device(@test_realm, hw_id)
    end

    test "succeeds and generates new credentials_secret with registered and not confirmed device" do
      hw_id = DatabaseTestHelper.registered_not_confirmed_hw_id()

      first_registration = DatabaseTestHelper.get_first_registration(hw_id)
      assert first_registration != nil

      assert {:ok, credentials_secret} = Engine.register_device(@test_realm, hw_id)

      assert credentials_secret !=
               DatabaseTestHelper.registered_not_confirmed_credentials_secret()

      assert DatabaseTestHelper.get_first_registration(hw_id) == first_registration
    end

    test "succeeds with unregistered and not confirmed device with 128 bit id" do
      hw_id = DatabaseTestHelper.unregistered_128_bit_hw_id()

      assert DatabaseTestHelper.get_first_registration(hw_id) == nil

      assert {:ok, _credentials_secret} = Engine.register_device(@test_realm, hw_id)

      first_registration = DatabaseTestHelper.get_first_registration(hw_id)
      now = TestHelper.now_millis()

      assert_in_delta first_registration, now, 1000
    end

    test "succeeds with unregistered and not confirmed device with 256 bit id" do
      hw_id = DatabaseTestHelper.unregistered_256_bit_hw_id()

      assert {:ok, _credentials_secret} = Engine.register_device(@test_realm, hw_id)
    end

    test "succeed and saves the introspection with initial_introspection" do
      hw_id = DatabaseTestHelper.unregistered_128_bit_hw_id()

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
               Engine.register_device(@test_realm, hw_id,
                 initial_introspection: initial_introspection
               )

      introspection = DatabaseTestHelper.get_introspection(hw_id)
      introspection_minor = DatabaseTestHelper.get_introspection_minor(hw_id)

      assert Enum.member?(introspection, {"org.astarteplatform.Values", 0})
      assert Enum.member?(introspection_minor, {"org.astarteplatform.Values", 3})

      assert Enum.member?(introspection, {"org.astarteplatform.OtherValues", 1})
      assert Enum.member?(introspection_minor, {"org.astarteplatform.OtherValues", 2})
    end

    test "fails when device_registration_limit is reached" do
      DatabaseTestHelper.set_device_registration_limit(@test_realm, 0)
      hw_id = DatabaseTestHelper.unregistered_128_bit_hw_id()

      assert DatabaseTestHelper.get_first_registration(hw_id) == nil

      assert {:error, :device_registration_limit_reached} =
               Engine.register_device(@test_realm, hw_id)
    end
  end

  describe "unregister device" do
    setup [:seed_devices]

    test "fails with non-existing realm" do
      realm = "nonexisting"
      device_id = TestHelper.random_128_bit_hw_id()

      assert {:error, :realm_not_found} = Engine.unregister_device(realm, device_id)
    end

    test "fails with invalid device_id" do
      assert {:error, :invalid_device_id} = Engine.unregister_device(@test_realm, "invalid")
    end

    test "fails with never registered device_id" do
      device_id = DatabaseTestHelper.unregistered_128_bit_hw_id()

      assert {:error, :device_not_registered} = Engine.unregister_device(@test_realm, device_id)
    end

    test "succeeds with registered and confirmed device_id, and makes it possible to register it again" do
      device_id = DatabaseTestHelper.registered_and_confirmed_128_hw_id()

      assert :ok = Engine.unregister_device(@test_realm, device_id)

      assert {:ok, _credentials_secret} = Engine.register_device(@test_realm, device_id)
    end

    test "succeeds when unregistering the same device multiple times" do
      device_id = DatabaseTestHelper.registered_and_confirmed_128_hw_id()

      assert :ok = Engine.unregister_device(@test_realm, device_id)

      assert :ok = Engine.unregister_device(@test_realm, device_id)
    end
  end

  describe "get_credentials" do
    setup [:seed_devices, :registered_device]

    test "fails with invalid secret", %{hw_id: hw_id} do
      secret = CredentialsSecret.generate()

      assert {:error, :forbidden} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )
    end

    test "fails with invalid protocol", %{hw_id: hw_id} do
      secret = CredentialsSecret.generate()

      assert {:error, :unknown_protocol} =
               Engine.get_credentials(
                 :other_protocol,
                 %{other: "params"},
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )
    end

    test "fails with invalid IP", %{hw_id: hw_id, secret: secret} do
      invalid_ip = "300.21.251.3"

      assert {:error, :invalid_ip} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 invalid_ip
               )
    end

    test "fails with unexisting realm", %{hw_id: hw_id, secret: secret} do
      realm = "unexisting"

      assert {:error, :realm_not_found} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 realm,
                 hw_id,
                 secret,
                 @valid_ip
               )
    end

    test "fails with not registered device" do
      secret = CredentialsSecret.generate()
      hw_id = DatabaseTestHelper.unregistered_256_bit_hw_id()

      assert {:error, :device_not_found} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )
    end

    test "fails with inhibited device" do
      hw_id = DatabaseTestHelper.registered_and_inhibited_hw_id()
      secret = DatabaseTestHelper.registered_and_inhibited_credentials_secret()

      assert {:error, :credentials_request_inhibited} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )
    end

    test "suceeds with valid CSR and uses encoded 128 bit device_id as common name with 256 bit hw_id",
         %{
           hw_id: hw_id,
           secret: secret
         } do
      assert {:ok, %{client_crt: crt}} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )

      # Make sure the original hw_id is 256 bit long
      {:ok, decoded_hw_id} = Base.url_decode64(hw_id, padding: false)
      assert byte_size(decoded_hw_id) == 32

      {:ok, device_id} = Device.decode_device_id(hw_id, allow_extended_id: true)
      encoded_device_id = Device.encode_device_id(device_id)

      expected_cn = "#{@test_realm}/#{encoded_device_id}"

      assert CertUtils.common_name!(crt) == expected_cn
    end

    test "suceeds with valid CSR and uses hw_id (== encoded device_id) as common name with 128 bit hw_id" do
      hw_id = DatabaseTestHelper.registered_and_confirmed_128_hw_id()
      secret = DatabaseTestHelper.registered_and_confirmed_128_credentials_secret()

      assert {:ok, %{client_crt: crt}} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )

      expected_cn = "#{@test_realm}/#{hw_id}"

      assert CertUtils.common_name!(crt) == expected_cn
    end

    test "revokes the crt if repeated", %{hw_id: hw_id, secret: secret} do
      assert {:ok, %{client_crt: _first_certificate}} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )

      assert {:ok, %{client_crt: second_certificate}} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )

      second_aki = CertUtils.authority_key_identifier!(second_certificate)
      second_serial = CertUtils.serial_number!(second_certificate)

      {:ok, device_id} = Device.decode_device_id(hw_id, allow_extended_id: true)

      db_client =
        Config.cassandra_node!()
        |> CQEx.Client.new!(keyspace: @test_realm)

      {:ok, device} = Queries.select_device_for_credentials_request(db_client, device_id)

      assert device[:cert_aki] == second_aki
      assert device[:cert_serial] == second_serial
    end

    test "retains first_credentials_request timestamp" do
      hw_id = DatabaseTestHelper.registered_not_confirmed_hw_id()
      secret = DatabaseTestHelper.registered_not_confirmed_credentials_secret()

      {:ok, device_id} = Device.decode_device_id(hw_id, allow_extended_id: true)

      db_client =
        Config.cassandra_node!()
        |> CQEx.Client.new!(keyspace: @test_realm)

      {:ok, no_credentials_requested_device} =
        Queries.select_device_for_credentials_request(db_client, device_id)

      assert no_credentials_requested_device[:first_credentials_request] == nil

      assert {:ok, %{client_crt: _first_certificate}} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )

      {:ok, credentials_requested_device} =
        Queries.select_device_for_credentials_request(db_client, device_id)

      first_credentials_request_timestamp =
        credentials_requested_device[:first_credentials_request]

      assert first_credentials_request_timestamp != nil

      assert {:ok, %{client_crt: _second_certificate}} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )

      {:ok, credentials_requested_again_device} =
        Queries.select_device_for_credentials_request(db_client, device_id)

      assert first_credentials_request_timestamp ==
               credentials_requested_again_device[:first_credentials_request]
    end
  end

  defp seed_devices(_context) do
    :ok = DatabaseTestHelper.seed_devices()

    on_exit(fn ->
      DatabaseTestHelper.set_device_registration_limit(@test_realm, nil)
      :ok = DatabaseTestHelper.clean_devices()
    end)
  end

  defp registered_device(_context) do
    hw_id = DatabaseTestHelper.registered_and_confirmed_256_hw_id()
    secret = DatabaseTestHelper.registered_and_confirmed_256_credentials_secret()

    {:ok, hw_id: hw_id, secret: secret}
  end
end
