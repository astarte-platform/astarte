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
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.RealmManagement.API.Interfaces do
  alias Astarte.Core.Interface
  alias Astarte.RealmManagement.API.RPC.RealmManagement

  require Logger

  def list_interfaces(realm_name) do
    RealmManagement.get_interfaces_list(realm_name)
  end

  def list_interface_major_versions(realm_name, id) do
    for interface_version <- RealmManagement.get_interface_versions_list(realm_name, id) do
      interface_version[:major_version]
    end
  end

  def get_interface(realm_name, interface_name, interface_major_version) do
    RealmManagement.get_interface(realm_name, interface_name, interface_major_version)
  end

  def create_interface(realm_name, params) do
    changeset = Interface.changeset(%Interface{}, params)

    with {:ok, %Interface{} = interface} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, interface_source} <- Poison.encode(interface),
         {:ok, :started} <- RealmManagement.install_interface(realm_name, interface_source) do
      {:ok, interface}
    end
  end

  def update_interface(realm_name, interface_name, major_version, params) do
    changeset = Interface.changeset(%Interface{}, params)

    with {:ok, %Interface{} = interface} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:name_matches, true} <- {:name_matches, interface_name == interface.name},
         {:major_matches, true} <- {:major_matches, major_version == interface.major_version},
         {:ok, interface_source} <- Poison.encode(interface) do
      RealmManagement.update_interface(realm_name, interface_source)
    else
      {:name_matches, false} ->
        {:error, :name_not_matching}

      {:major_matches, false} ->
        {:error, :major_version_not_matching}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete_interface(realm_name, interface_name, interface_major_version, _attrs \\ %{}) do
    RealmManagement.delete_interface(realm_name, interface_name, interface_major_version)
  end
end
