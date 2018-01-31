defmodule Astarte.RealmManagement.API.Auth.User do
  @enforce_keys [:id]
  defstruct [
    :id,
    :authorizations
  ]
end
