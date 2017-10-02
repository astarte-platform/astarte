defmodule Astarte.Pairing.Config do
  @moduledoc """
  This module helps the access to the runtime configuration of Astarte Pairing
  """

  @doc """
  Returns the rpc_queue contained in the config.

  Raises if it doesn't exist since it's required.
  """
  def rpc_queue! do
    Application.fetch_env!(:astarte_pairing, :rpc_queue)
  end

  @doc """
  Returns the amqp_connection options or an empty list if they're not set.
  """
  def amqp_options do
    Application.get_env(:astarte_pairing, :amqp_connection, [])
  end
end
