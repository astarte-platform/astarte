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

  alias Astarte.Pairing.APIKey
  alias Astarte.Pairing.Config
  alias Astarte.Pairing.DatabaseTestHelper
  alias Astarte.Pairing.Engine
  alias Astarte.Pairing.Queries
  alias Astarte.Pairing.TestHelper
  alias Astarte.Pairing.Utils
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

  @valid_ip "2.3.4.5"

  setup_all do
    DatabaseTestHelper.seed_db()

    on_exit fn ->
      DatabaseTestHelper.drop_db()
    end
  end

  setup do
    hw_id = TestHelper.random_hw_id()
    {:ok, api_key} = Engine.generate_api_key(@test_realm, hw_id)

    {:ok, api_key: api_key}
  end

  test "do_pairing with invalid APIKey" do
    assert Engine.do_pairing(@test_csr, "invalidapikey", @valid_ip) == {:error, :invalid_api_key}
  end

  test "do_pairing with invalid IP", %{api_key: api_key} do
    assert Engine.do_pairing(@test_csr, api_key, "300.3.4.5") == {:error, :invalid_ip}
  end

  test "do_pairing with unexisting realm encoded in API key" do
    {:ok, device_uuid} =
      TestHelper.random_hw_id()
      |> Utils.extended_id_to_uuid()

    {:ok, api_key} = APIKey.generate("unexisting", device_uuid, "api_salt")

    assert Engine.do_pairing(@test_csr, api_key, @valid_ip) == {:error, :shutdown}
  end

  test "do_pairing with unexisting device" do
    # We don't pass through Engine for the APIKey so the device
    # is never inserted in the DB
    {:ok, device_uuid} =
      TestHelper.random_hw_id()
      |> Utils.extended_id_to_uuid()

    {:ok, api_key} = APIKey.generate(@test_realm, device_uuid, "api_salt")

    assert Engine.do_pairing(@test_csr, api_key, @valid_ip) == {:error, :device_not_found}
  end

  test "valid pairing", %{api_key: api_key} do
    assert {:ok, _crt} = Engine.do_pairing(@test_csr, api_key, @valid_ip)
  end

  test "revocation if pairing is repeated", %{api_key: api_key} do
    assert {:ok, _first_certificate} = Engine.do_pairing(@test_csr, api_key, @valid_ip)
    assert {:ok, second_certificate} = Engine.do_pairing(@test_csr, api_key, @valid_ip)

    second_aki = CertUtils.authority_key_identifier!(second_certificate)
    second_serial = CertUtils.serial_number!(second_certificate)

    {:ok, %{realm: realm, device_uuid: device_uuid}} = APIKey.verify(api_key, "api_salt")

    db_client =
      Config.cassandra_node()
      |> CQEx.Client.new!(keyspace: realm)

    {:ok, device} = Queries.select_device_for_pairing(db_client, device_uuid)

    assert device[:cert_aki] == second_aki
    assert device[:cert_serial] == second_serial
  end

  test "first_pairing timestamp", %{api_key: api_key} do
    {:ok, %{realm: realm, device_uuid: device_uuid}} = APIKey.verify(api_key, "api_salt")

    db_client =
      Config.cassandra_node()
      |> CQEx.Client.new!(keyspace: realm)

    {:ok, no_paired_device} = Queries.select_device_for_pairing(db_client, device_uuid)
    assert no_paired_device[:first_pairing] == :null

    assert {:ok, _first_certificate} = Engine.do_pairing(@test_csr, api_key, @valid_ip)
    {:ok, paired_device} = Queries.select_device_for_pairing(db_client, device_uuid)
    first_pairing_timestamp = paired_device[:first_pairing]
    assert first_pairing_timestamp != :null

    assert {:ok, _second_certificate} = Engine.do_pairing(@test_csr, api_key, @valid_ip)
    {:ok, repaired_device} = Queries.select_device_for_pairing(db_client, device_uuid)
    assert first_pairing_timestamp == repaired_device[:first_pairing]
  end
end
