defmodule Astarte.Pairing.API.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  @doc """
  Returns the AMQP queue for the RPC
  """
  def rpc_queue do
    Application.get_env(:astarte_pairing_api, :rpc_queue)
  end

  @doc """
  Returns the AMQP connection options
  """
  def amqp_options do
    Application.get_env(:astarte_pairing_api, :amqp_options)
  end
end
