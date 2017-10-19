defmodule Astarte.Pairing.APIWeb.BrokerInfoView do
  use Astarte.Pairing.APIWeb, :view
  alias Astarte.Pairing.APIWeb.BrokerInfoView

  def render("show.json", %{broker_info: broker_info}) do
    %{data: render_one(broker_info, BrokerInfoView, "broker_info.json")}
  end

  def render("broker_info.json", %{broker_info: broker_info}) do
    %{url: broker_info.url,
      version: broker_info.version}
  end
end
