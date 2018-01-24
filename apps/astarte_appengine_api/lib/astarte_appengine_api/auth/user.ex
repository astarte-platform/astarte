defmodule Astarte.AppEngine.API.Auth.User do
  @enforce_keys [:id]
  defstruct [
    :id,
    :authorizations
  ]
end
