defmodule Astarte.RealmManagement.APIWeb.InterfaceVersionView do
  use Astarte.RealmManagement.APIWeb, :view

  def render("index.json", %{interfaces: interfaces}) do
    interfaces
  end

  def render("show.json", %{interface: interface}) do
    interface
  end

end
