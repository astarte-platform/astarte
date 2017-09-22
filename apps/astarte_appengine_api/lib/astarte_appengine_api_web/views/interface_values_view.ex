defmodule AstarteAppengineApiWeb.InterfaceValuesView do
  use AstarteAppengineApiWeb, :view
  alias AstarteAppengineApiWeb.InterfaceValuesView

  def render("index.json", %{interfaces: interfaces}) do
    %{data: render_many(interfaces, InterfaceValuesView, "interface_values.json")}
  end

  def render("show.json", %{interface_values: interface_values}) do
    %{data: render_one(interface_values, InterfaceValuesView, "interface_values.json")}
  end

  def render("interface_values.json", %{interface_values: interface_values}) do
    %{id: interface_values.id}
  end
end
