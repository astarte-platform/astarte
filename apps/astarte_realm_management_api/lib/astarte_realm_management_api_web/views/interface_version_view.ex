defmodule Astarte.RealmManagement.API.Web.InterfaceVersionView do
  use Astarte.RealmManagement.API.Web, :view

  def render("index.json", %{interfaces: interfaces}) do
    interfaces
  end

  def render("show.json", %{interface: interface}) do
    interface
  end

end
