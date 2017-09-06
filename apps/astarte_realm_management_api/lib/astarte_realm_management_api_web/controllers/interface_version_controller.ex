defmodule Astarte.RealmManagement.APIWeb.InterfaceVersionController do
  use Astarte.RealmManagement.APIWeb, :controller

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name, "id" => id}) do
    interfaces = Astarte.RealmManagement.API.Interfaces.list_interface_major_versions!(realm_name, id)
    render(conn, "index.json", interfaces: interfaces)
  end

end
