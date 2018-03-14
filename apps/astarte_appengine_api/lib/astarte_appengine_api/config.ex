defmodule Astarte.AppEngine.API.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  @doc """
  Returns the MQTT options
  """
  def mqtt_options do
    Application.get_env(:astarte_appengine_api, :mqtt_options, [])
  end

  @doc """
  Returns true if the authentication is disabled
  """
  def authentication_disabled? do
    Application.get_env(:astarte_appengine_api, :disable_authentication, false)
  end

  @doc """
  Returns the max query limit that is configured or nil if there's no limit
  """
  def max_results_limit do
    limit = Application.get_env(:astarte_appengine_api, :max_results_limit)

    if limit > 0 do
      limit
    else
      # If limit <= 0, no limit
      nil
    end
  end
end
