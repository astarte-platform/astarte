defmodule Astarte.RealmManagement.API.Web.InterfaceView do
  use Astarte.RealmManagement.API.Web, :view
  alias Astarte.RealmManagement.API.Web.InterfaceView

  def render("index.json", %{interfaces: interfaces}) do
    %{data: render_many(interfaces, InterfaceView, "interface.json")}
  end

  def render("show.json", %{interface: interface}) do
    %{data: render_one(interface, InterfaceView, "interface.json")}
  end

  def render("interface.json", %{interface: interface}) do
    %{id: interface.id}
  end
end
