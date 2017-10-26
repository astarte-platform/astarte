defmodule Astarte.Pairing.APIWeb.TestJWTProducer do
  use Guardian, otp_app: :astarte_pairing_api

  alias Astarte.Pairing.API.Agent.Realm

  def build_claims(claims, %Realm{realm_name: realm_name}, _opts) do
    new_claims =
      claims
      |> Map.delete("sub")
      |> Map.put("routingTopic", realm_name)

    {:ok, new_claims}
  end

  def subject_for_token(%Realm{realm_name: realm_name}, _claims) do
    {:ok, realm_name}
  end

  def resource_from_claims(claims) do
    {:ok, %Realm{realm_name: claims["routingTopic"]}}
  end
end
