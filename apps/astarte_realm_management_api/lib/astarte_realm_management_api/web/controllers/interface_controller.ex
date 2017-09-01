defmodule Astarte.RealmManagement.API.Web.InterfaceController do
  use Astarte.RealmManagement.API.Web, :controller

  action_fallback Astarte.RealmManagement.API.Web.FallbackController

  def index(conn, %{"realm_name" => realm_name}) do
    interfaces = Astarte.RealmManagement.API.Interfaces.list_interfaces!(realm_name)
    render(conn, "index.json", interfaces: interfaces)
  end

  def create(conn, %{"realm_name" => realm_name, "data" => interface_source}) do
    doc = Astarte.Core.InterfaceDocument.from_json(interface_source)

    with {:ok, :started} <- Astarte.RealmManagement.API.Interfaces.create_interface!(realm_name, interface_source) do
      conn
      |> put_resp_header("location", interface_path(conn, :show, realm_name, doc.descriptor.name, Integer.to_string(doc.descriptor.major_version)))
      |> send_resp(:created, "")
    end
  end

  def show(conn, %{"realm_name" => realm_name, "id" => id, "major_version" => major_version}) do
    {parsed_major, ""} = Integer.parse(major_version)
    interface_source = Astarte.RealmManagement.API.Interfaces.get_interface!(realm_name, id, parsed_major)

    # do not use render here, just return a raw json, render would escape this and ecapsulate it inside an outer JSON object
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, interface_source)
  end

  def update(conn, %{"id" => id, "interface" => interface_params}) do
    interface = Astarte.RealmManagement.API.Interfaces.get_interface!(id)

    with {:ok, interface_source} <- Astarte.RealmManagement.API.Interfaces.update_interface(interface, interface_params) do
      render(conn, "show.json", interface: interface)
    end
  end

  def delete(conn, %{"id" => id}) do
    interface = Astarte.RealmManagement.API.Interfaces.get_interface!(id)
    with {:ok, interface_source} <- Astarte.RealmManagement.API.Interfaces.delete_interface(interface) do
      send_resp(conn, :no_content, "")
    end
  end
end
