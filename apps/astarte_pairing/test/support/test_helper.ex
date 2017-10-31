defmodule Astarte.Pairing.TestHelper do
  @valid_fallback_api_key "validfallbackapikey"

  def random_hw_id do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  def valid_fallback_api_key do
    @valid_fallback_api_key
  end

  def fallback_verify_key(@valid_fallback_api_key, _salt) do
    {:ok, "testrealm", :uuid.get_v4()}
  end

  def fallback_verify_key(_invalid_api_key, _salt) do
    {:error, :invalid_api_key}
  end
end
