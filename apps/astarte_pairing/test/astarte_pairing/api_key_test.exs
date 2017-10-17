defmodule Astarte.Pairing.APIKeyTest do
  use ExUnit.Case

  alias Astarte.Pairing.APIKey
  alias Astarte.Pairing.Utils

  @test_realm "testrealm"
  @test_hw_id :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

  test "APIKey round trip" do
    {:ok, device_uuid} = Utils.extended_id_to_uuid(@test_hw_id)
    {:ok, api_key} = APIKey.generate(@test_realm, device_uuid, "api_salt")

    assert APIKey.verify(api_key, "api_salt") == {:ok, %{realm: @test_realm, device_uuid: device_uuid}}
  end

  test "APIKey fails to verify if tampered" do
    {:ok, device_uuid} = Utils.extended_id_to_uuid(@test_hw_id)
    {:ok, api_key} = APIKey.generate(@test_realm, device_uuid, "api_salt")

    [prefix, _payload, postfix] = String.split(api_key, ".")

    tampered_payload =
      device_uuid <> "otherrealm"
      |> Base.url_encode64(padding: false)

    tampered_api_key = "#{prefix}.#{tampered_payload}.#{postfix}"

    assert APIKey.verify(tampered_api_key, "api_salt") == {:error, :invalid_api_key}
  end
end
