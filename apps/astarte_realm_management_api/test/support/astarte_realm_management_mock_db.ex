defmodule Astarte.RealmManagement.Mock.DB do
  alias Astarte.RealmManagement.API.JWTTestHelper

  def start_link do
    # TODO: this will be an Agent some day
    :ok
  end

  def interfaces_list(_realm) do
    []
  end

  def jwt_public_key_pem(_realm) do
    JWTTestHelper.public_key_pem()
  end
end
