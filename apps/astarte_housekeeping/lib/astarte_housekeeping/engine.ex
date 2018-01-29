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

defmodule Astarte.Housekeeping.Engine do
  use GenServer
  require Logger

  @timeout 10000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :astarte_housekeeping_engine)
  end

  def init(_opts) do
    client = CQEx.Client.new!()
    unless Astarte.Housekeeping.Queries.astarte_keyspace_exists?(client) do
      Logger.info("Astarte keyspace not found, creating it")
      Astarte.Housekeeping.Queries.create_astarte_keyspace(client)
    end
    {:ok, client}
  end

  def create_realm(realm, public_key_pem, opts \\ []) do
    if opts[:async] do
      GenServer.cast(:astarte_housekeeping_engine, {:create_realm, realm, public_key_pem})
    else
      GenServer.call(:astarte_housekeeping_engine, {:create_realm, realm, public_key_pem}, @timeout)
    end
  end

  def realm_exists?(realm) do
    GenServer.call(:astarte_housekeeping_engine, {:realm_exists, realm})
  end

  def realms_list() do
    GenServer.call(:astarte_housekeeping_engine, {:realms_list})
  end

  def get_realm(realm) do
    GenServer.call(:astarte_housekeeping_engine, {:get_realm, realm})
  end

  def handle_cast({:create_realm, realm, public_key_pem}, client) do
    Astarte.Housekeeping.Queries.create_realm(client, realm, public_key_pem)
    {:noreply, client}
  end

  def handle_call({:create_realm, realm, public_key_pem}, _from, client) do
    reply = Astarte.Housekeeping.Queries.create_realm(client, realm, public_key_pem)
    {:reply, reply, client}
  end

  def handle_call({:realm_exists, realm}, _from, client) do
    reply = Astarte.Housekeeping.Queries.realm_exists?(client, realm)
    {:reply, reply, client}
  end

  def handle_call({:realms_list}, _from, client) do
    reply = Astarte.Housekeeping.Queries.realms_list(client)
    {:reply, reply, client}
  end

  def handle_call({:get_realm, realm}, _from, client) do
    reply = Astarte.Housekeeping.Queries.get_realm(client, realm)
    {:reply, reply, client}
  end
end
