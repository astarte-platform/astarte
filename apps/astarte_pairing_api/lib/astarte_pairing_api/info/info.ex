defmodule Astarte.Pairing.API.Info do
  @moduledoc """
  The Info context.
  """

  alias Astarte.Pairing.API.Info.BrokerInfo
  alias Astarte.Pairing.API.RPC.AMQPClient

  @doc """
  Gets broker_info.

  Raises if the Broker info does not exist.

  ## Examples

      iex> get_broker_info!()
      %BrokerInfo{url: "ssl://broker.example.com:1234", version: "1"}

  """
  def get_broker_info! do
    case AMQPClient.get_info do
      {:ok, %{url: url, version: version}} ->
        %BrokerInfo{url: url, version: version}

      _ ->
        raise "Broker info unavailable"
    end
  end
end
