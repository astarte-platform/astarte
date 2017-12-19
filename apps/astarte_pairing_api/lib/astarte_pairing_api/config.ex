defmodule Astarte.Pairing.API.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  @doc """
  Returns the JWT public key
  """
  def jwt_public_key do
    Application.get_env(:astarte_pairing_api, :jwt_public_key)
  end
end
