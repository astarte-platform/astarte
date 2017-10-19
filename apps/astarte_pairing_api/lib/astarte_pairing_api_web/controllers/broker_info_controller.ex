defmodule Astarte.Pairing.APIWeb.BrokerInfoController do
  use Astarte.Pairing.APIWeb, :controller

  alias Astarte.Pairing.API.Info
  alias Astarte.Pairing.API.Info.BrokerInfo

  action_fallback Astarte.Pairing.APIWeb.FallbackController

  def index(conn, _params) do
    broker_info = Pairing.API.Info.list_broker_info()
    render(conn, "index.json", broker_info: broker_info)
  end

  def create(conn, %{"broker_info" => broker_info_params}) do
    with {:ok, %BrokerInfo{} = broker_info} <- Pairing.API.Info.create_broker_info(broker_info_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", broker_info_path(conn, :show, broker_info))
      |> render("show.json", broker_info: broker_info)
    end
  end

  def show(conn, %{"id" => id}) do
    broker_info = Pairing.API.Info.get_broker_info!(id)
    render(conn, "show.json", broker_info: broker_info)
  end

  def update(conn, %{"id" => id, "broker_info" => broker_info_params}) do
    broker_info = Pairing.API.Info.get_broker_info!(id)

    with {:ok, %BrokerInfo{} = broker_info} <- Pairing.API.Info.update_broker_info(broker_info, broker_info_params) do
      render(conn, "show.json", broker_info: broker_info)
    end
  end

  def delete(conn, %{"id" => id}) do
    broker_info = Pairing.API.Info.get_broker_info!(id)
    with {:ok, %BrokerInfo{}} <- Pairing.API.Info.delete_broker_info(broker_info) do
      send_resp(conn, :no_content, "")
    end
  end
end
