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

defmodule Astarte.Housekeeping.Engine do
  require Logger

  alias CQEx.Client, as: DatabaseClient

  alias Astarte.Housekeeping.Queries

  def init do
    client = CQEx.Client.new!()

    unless Queries.astarte_keyspace_exists?(client) do
      Logger.info("Astarte keyspace not found, creating it")
      Queries.create_astarte_keyspace(client)
    else
      :ok
    end
  end

  def create_realm(realm, public_key_pem, replication_factor, opts \\ []) do
    Logger.info(
      "create_realm: creating #{realm} with replication: #{inspect(replication_factor)}"
    )

    client = get_db_client()

    if opts[:async] do
      {:ok, _pid} =
        Task.start(Queries, :create_realm, [client, realm, public_key_pem, replication_factor])

      :ok
    else
      Queries.create_realm(client, realm, public_key_pem, replication_factor)
    end
  end

  def get_realm(realm) do
    get_db_client()
    |> Queries.get_realm(realm)
  end

  def realm_exists?(realm) do
    get_db_client()
    |> Queries.realm_exists?(realm)
  end

  def realms_list() do
    get_db_client()
    |> Queries.realms_list()
  end

  defp get_db_client do
    DatabaseClient.new!()
  end
end
