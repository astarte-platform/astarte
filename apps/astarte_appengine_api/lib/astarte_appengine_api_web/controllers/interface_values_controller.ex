defmodule AstarteAppengineApiWeb.InterfaceValuesController do
  use AstarteAppengineApiWeb, :controller

  alias AstarteAppengineApi.Device
  alias AstarteAppengineApi.Device.InterfaceValues

  action_fallback AstarteAppengineApiWeb.FallbackController

  def index(conn, _params) do
    interfaces = Device.list_interfaces()
    render(conn, "index.json", interfaces: interfaces)
  end

  def create(conn, %{"interface_values" => interface_values_params}) do
    with {:ok, %InterfaceValues{} = interface_values} <- Device.create_interface_values(interface_values_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", interface_values_path(conn, :show, interface_values))
      |> render("show.json", interface_values: interface_values)
    end
  end

  def show(conn, %{"id" => id}) do
    interface_values = Device.get_interface_values!(id)
    render(conn, "show.json", interface_values: interface_values)
  end

  def update(conn, %{"id" => id, "interface_values" => interface_values_params}) do
    interface_values = Device.get_interface_values!(id)

    with {:ok, %InterfaceValues{} = interface_values} <- Device.update_interface_values(interface_values, interface_values_params) do
      render(conn, "show.json", interface_values: interface_values)
    end
  end

  def delete(conn, %{"id" => id}) do
    interface_values = Device.get_interface_values!(id)
    with {:ok, %InterfaceValues{}} <- Device.delete_interface_values(interface_values) do
      send_resp(conn, :no_content, "")
    end
  end
end
