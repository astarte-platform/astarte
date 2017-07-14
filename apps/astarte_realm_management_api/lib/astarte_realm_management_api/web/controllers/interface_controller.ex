defmodule Astarte.RealmManagement.API.Web.InterfaceController do
  use Astarte.RealmManagement.API.Web, :controller

  alias Astarte.Core.InterfaceDocument, as: Interface

  action_fallback Astarte.RealmManagement.API.Web.FallbackController

  def index(conn, %{"realm_name" => realm_name}) do
    interfaces = Astarte.RealmManagement.API.Interfaces.list_interfaces(realm_name)
    render(conn, "index.json", interfaces: interfaces)
  end

  def create(conn, %{"interface" => interface_params}) do
    with {:ok, %Interface{} = interface} <- Astarte.RealmManagement.API.Interfaces.create_interface(interface_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", interface_path(conn, :show, interface))
      |> render("show.json", interface: interface)
    end
  end

  def show(conn, %{"realm_name" => realm_name, "id" => id}) do
    interface = Astarte.RealmManagement.API.Interfaces.get_interface!(realm_name, id)
    render(conn, "show.json", interface: interface)
  end

end
