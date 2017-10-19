defmodule Astarte.Pairing.APIWeb.BrokerInfoController do
  use Astarte.Pairing.APIWeb, :controller

  alias Astarte.Pairing.API.Info
  alias Astarte.Pairing.API.Info.BrokerInfo

  action_fallback Astarte.Pairing.APIWeb.FallbackController

  def show(conn, %{}) do
    broker_info = Info.get_broker_info!(id)
    render(conn, "show.json", broker_info: broker_info)
  end
end
