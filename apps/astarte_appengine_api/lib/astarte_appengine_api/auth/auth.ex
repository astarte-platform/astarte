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
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.AppEngine.API.Auth do
  alias Astarte.AppEngine.API.Queries
  alias Astarte.DataAccess.Database

  require Logger

  def fetch_public_key(realm) do
    cass_node = List.first(Application.get_env(:cqerl, :cassandra_nodes))

    with {:ok, client} <- Database.connect(realm),
         {:ok, public_key} <- Queries.fetch_public_key(client) do
      {:ok, public_key}
    else
      {:error, :public_key_not_found} ->
        Logger.warn("No public key found in realm #{realm}")
        {:error, :public_key_not_found}

      {:error, :database_connection_error} ->
        Logger.info("Auth request for unexisting realm #{realm}")
        # TODO: random busy wait here to prevent realm enumeration
        {:error, :not_existing_realm}
    end
  end
end
