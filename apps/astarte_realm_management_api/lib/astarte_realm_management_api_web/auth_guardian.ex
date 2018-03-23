defmodule Astarte.RealmManagement.APIWeb.AuthGuardian do
  use Guardian, otp_app: :astarte_realm_management_api

  alias Astarte.RealmManagement.API.Auth.User

  def subject_for_token(%User{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def resource_from_claims(claims) do
    {:ok,
     %User{
       id: claims["sub"],
       authorizations: Map.get(claims, "a_rma", [])
     }}
  end
end
