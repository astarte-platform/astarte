defmodule Astarte.RealmManagement.API.Interfaces do

  alias Astarte.RealmManagement.API.Interfaces.RPC.AMQPClient

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
    AMQPClient.get_interface(realm_name, interface_name, interface_major_version)
  end

  def create_interface!(realm_name, interface_source, _attrs \\ %{}) do
    AMQPClient.install_interface(realm_name, interface_source)
  end

end
