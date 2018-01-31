#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.RealmManagement.API.Interfaces do

  alias Astarte.RealmManagement.API.RPC.AMQPClient

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

  def update_interface!(realm_name, interface_source, _attrs \\ %{}) do
    AMQPClient.update_interface(realm_name, interface_source)
  end

  def delete_interface!(realm_name, interface_name, interface_major_version, _attrs \\ %{}) do
    AMQPClient.delete_interface(realm_name, interface_name, interface_major_version)
  end

end
