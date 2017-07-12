defmodule Astarte.RealmManagement.API.Web.InterfaceController do
  use Astarte.RealmManagement.API.Web, :controller

  alias Astarte.RealmManagement.API.Interfaces
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

  def update(conn, %{"id" => id, "interface" => interface_params}) do
    interface = Astarte.RealmManagement.API.Interfaces.get_interface!(id)

    with {:ok, %Interface{} = interface} <- Astarte.RealmManagement.API.Interfaces.update_interface(interface, interface_params) do
      render(conn, "show.json", interface: interface)
    end
  end

  def delete(conn, %{"id" => id}) do
    interface = Astarte.RealmManagement.API.Interfaces.get_interface!(id)
    with {:ok, %Interface{}} <- Astarte.RealmManagement.API.Interfaces.delete_interface(interface) do
      send_resp(conn, :no_content, "")
    end
  end
end
