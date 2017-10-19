defmodule Astarte.Pairing.APIWeb.BrokerInfoView do
  use Astarte.Pairing.APIWeb, :view
  alias Astarte.Pairing.APIWeb.BrokerInfoView

  def render("index.json", %{broker_info: broker_info}) do
    %{data: render_many(broker_info, BrokerInfoView, "broker_info.json")}
  end

  def render("show.json", %{broker_info: broker_info}) do
    %{data: render_one(broker_info, BrokerInfoView, "broker_info.json")}
  end

  def render("broker_info.json", %{broker_info: broker_info}) do
    %{id: broker_info.id}
  end
end
