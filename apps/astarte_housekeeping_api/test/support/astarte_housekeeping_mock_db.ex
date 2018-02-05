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

defmodule Astarte.Housekeeping.Mock.DB do
  alias Astarte.Housekeeping.API.Realms.Realm

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put_realm(realm = %Realm{realm_name: realm_name, jwt_public_key_pem: _pem}) do
    Agent.update(__MODULE__, &Map.put(&1, realm_name, realm))
  end

  def get_realm(realm_name) do
    Agent.get(__MODULE__, &Map.get(&1, realm_name))
  end

  def realm_exists?(realm_name) do
    Agent.get(__MODULE__, &Map.has_key?(&1, realm_name))
  end

  def realms_list do
    Agent.get(__MODULE__, &Map.keys(&1))
  end
end
