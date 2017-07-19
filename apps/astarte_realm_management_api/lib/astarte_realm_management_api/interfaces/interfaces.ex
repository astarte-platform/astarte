defmodule Astarte.RealmManagement.API.Interfaces do

  alias Astarte.RealmManagement.API.Repo
  alias Astarte.RealmManagement.API.Interfaces.RPC.AMQPClient
  alias Astarte.Core.InterfaceDocument, as: Interface

  require Logger

  def list_interfaces!(realm_name) do
    AMQPClient.get_interfaces_list(realm_name)
  end

  def list_interface_major_versions!(realm_name, id) do
    for interface_version <- AMQPClient.get_interface_versions_list(realm_name, id) do
      interface_version[:major_version]
    end
  end

  def get_interface!(realm_name, interface_name, interface_major_version) do
    Logger.warn "get_interfaces: " <> realm_name <> " " <> interface_name <> " " <> interface_major_version
    raise "TODO"
  end

  def create_interface!(attrs \\ %{}) do
    Logger.warn "create_interface: " <> inspect(attrs)
    raise "TODO"
  end

end
