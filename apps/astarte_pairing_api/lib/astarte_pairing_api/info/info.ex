defmodule Astarte.Pairing.API.Info do
  @moduledoc """
  The Info context.
  """

  alias Astarte.Pairing.API.Info.BrokerInfo

  @doc """
  Gets broker_info.

  Raises if the Broker info does not exist.

  ## Examples

      iex> get_broker_info!(123)
      %BrokerInfo{}

  """
  def get_broker_info!(id), do: raise "TODO"
end
