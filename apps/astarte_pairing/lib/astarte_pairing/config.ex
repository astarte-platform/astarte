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
end
