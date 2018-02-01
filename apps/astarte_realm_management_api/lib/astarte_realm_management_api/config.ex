defmodule Astarte.RealmManagement.API.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  @doc """
  Returns true if the authentication is disabled
  """
  def authentication_disabled? do
    Application.get_env(:astarte_realm_management_api, :disable_authentication, false)
  end
end
