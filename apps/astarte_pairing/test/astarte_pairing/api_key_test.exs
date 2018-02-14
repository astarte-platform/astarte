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

defmodule Astarte.Pairing.APIKeyTest do
  use ExUnit.Case

  alias Astarte.Pairing.APIKey
  alias Astarte.Pairing.TestHelper
  alias Astarte.Pairing.Utils

  @test_realm "testrealm"
  @test_hw_id :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

  test "APIKey round trip" do
    {:ok, device_uuid} = Utils.extended_id_to_uuid(@test_hw_id)
    {:ok, api_key} = APIKey.generate(@test_realm, device_uuid, "api_salt")

    assert APIKey.verify(api_key, "api_salt") ==
             {:ok, %{realm: @test_realm, device_uuid: device_uuid}}
  end

  test "APIKey fails to verify if tampered" do
    {:ok, device_uuid} = Utils.extended_id_to_uuid(@test_hw_id)
    {:ok, api_key} = APIKey.generate(@test_realm, device_uuid, "api_salt")

    [prefix, _payload, postfix] = String.split(api_key, ".")

    tampered_payload =
      (device_uuid <> "otherrealm")
      |> Base.url_encode64(padding: false)

    tampered_api_key = "#{prefix}.#{tampered_payload}.#{postfix}"

    assert APIKey.verify(tampered_api_key, "api_salt") == {:error, :invalid_api_key}
  end

  test "APIKey fallback verify" do
    Application.put_env(
      :astarte_pairing,
      :fallback_api_key_verify_fun,
      {Astarte.Pairing.TestHelper, :fallback_verify_key}
    )

    assert {:ok, _realm, _uuid} = APIKey.verify(TestHelper.valid_fallback_api_key(), "api_salt")
    assert {:error, :invalid_api_key} = APIKey.verify("invalid", "api_salt")

    on_exit(fn ->
      Application.delete_env(:astarte_pairing, :fallback_api_key_verify_fun)
    end)
  end
end
