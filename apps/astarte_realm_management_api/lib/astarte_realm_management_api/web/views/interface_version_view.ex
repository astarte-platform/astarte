defmodule Astarte.RealmManagement.API.Web.InterfaceVersionView do
  use Astarte.RealmManagement.API.Web, :view
  alias Astarte.RealmManagement.API.Web.InterfaceVersionView

  def render("index.json", %{interfaces: interfaces}) do
    interfaces
  end

  def render("show.json", %{interface: interface}) do
    interface
  end

end
