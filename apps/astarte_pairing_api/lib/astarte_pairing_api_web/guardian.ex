defmodule Astarte.Pairing.APIWeb.Guardian do
  use Guardian, otp_app: :astarte_pairing_api

  alias Astarte.Pairing.API.Agent.Realm

  def subject_for_token(%Realm{realm_name: realm_name}, _claims) do
    {:ok, realm_name}
  end

  def resource_from_claims(claims) do
    {:ok, %Realm{realm_name: claims["routingTopic"]}}
  end
end
