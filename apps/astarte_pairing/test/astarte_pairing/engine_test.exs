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
# Copyright (C) 2017 Ispirata Srl
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

  describe "register_device" do
    setup [:seed_devices]

    test "fails with non-existing realm" do
      hw_id = TestHelper.random_hw_id()
      realm = "nonexisting"

      assert {:error, :realm_not_found} = Engine.register_device(realm, hw_id)
    end

    test "fails with invalid hw_id" do
      hw_id = "invalid"

      assert {:error, :invalid_device_id} = Engine.register_device(@test_realm, hw_id)
    end

    test "fails with registered and confirmed device" do
      hw_id = DatabaseTestHelper.registered_and_confirmed_hw_id()

      assert {:error, :already_registered} = Engine.register_device(@test_realm, hw_id)
    end

    test "succeeds and generates new credentials_secret with registered and not confirmed device" do
      hw_id = DatabaseTestHelper.registered_not_confirmed_hw_id()

      assert {:ok, credentials_secret} = Engine.register_device(@test_realm, hw_id)

      assert credentials_secret !=
               DatabaseTestHelper.registered_not_confirmed_credentials_secret()
    end

    test "succeeds with unregistered and not confirmed device" do
      hw_id = DatabaseTestHelper.unregistered_hw_id()

      assert {:ok, _credentials_secret} = Engine.register_device(@test_realm, hw_id)
    end
  end

  describe "get_credentials" do
    setup [:seed_devices, :registered_device]

    test "fails with invalid secret", %{hw_id: hw_id} do
      secret = CredentialsSecret.generate()

      assert {:error, :unauthorized} =
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
      hw_id = DatabaseTestHelper.unregistered_hw_id()

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

    test "suceeds with valid pairing", %{hw_id: hw_id, secret: secret} do
      assert {:ok, _crt} =
               Engine.get_credentials(
                 @astarte_protocol,
                 @astarte_credentials_params,
                 @test_realm,
                 hw_id,
                 secret,
                 @valid_ip
               )
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
        Config.cassandra_node()
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
        Config.cassandra_node()
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
      :ok = DatabaseTestHelper.clean_devices()
    end)
  end

  defp registered_device(_context) do
    hw_id = DatabaseTestHelper.registered_and_confirmed_hw_id()
    secret = DatabaseTestHelper.registered_and_confirmed_credentials_secret()

    {:ok, hw_id: hw_id, secret: secret}
  end
end
