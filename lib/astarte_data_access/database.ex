#
# Copyright (C) 2018 Ispirata Srl
#
# This file is part of Astarte.
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#

defmodule Astarte.DataAccess.Database do
  require Logger

  @spec connect() :: {:ok, :cqerl.client()} | {:error, atom}
  def connect() do
    with {:nodes, nodes} when is_list(nodes) <- {:nodes, Application.get_env(:cqerl, :cassandra_nodes)},
         {:node, node} when is_tuple(node) <- {:node, Enum.random(nodes)},
         {:ok, client} <- CQEx.Client.new(node) do
      {:ok, client}
    else
      {:error, :shutdown} ->
        {:error, :database_connection_error}

      {:nodes, nil} ->
        Logger.error("Database is not configured.")
        {:error, :database_connection_error}

      {:node, any} ->
        Logger.error("Database looks misconfigured: #{inspect(any)}.")
        {:error, :database_connection_error}

      any_error ->
        Logger.warn("Failed connection to the database. Reason: #{inspect(any_error)}")
        {:error, :database_connection_error}
    end
  end

  @spec connect(String.t()) :: {:ok, :cqerl.client()} | {:error, atom}
  def connect(realm_name) when is_binary(realm_name) do
    with {:nodes, nodes} when is_list(nodes) <- {:nodes, Application.get_env(:cqerl, :cassandra_nodes)},
         {:node, node} when is_tuple(node) <- {:node, Enum.random(nodes)},
         {:ok, client} <- CQEx.Client.new(node, keyspace: realm_name) do
      {:ok, client}
    else
      {:error, :shutdown} ->
        {:error, :database_connection_error}

      {:nodes, nil} ->
        Logger.error("Database is not configured.")
        {:error, :database_connection_error}

      {:node, any} ->
        Logger.error("Database looks misconfigured: #{inspect(any)}.")
        {:error, :database_connection_error}

      any_error ->
        Logger.warn("Failed connection to realm #{realm_name}. Reason: #{inspect(any_error)}")
        {:error, :database_connection_error}
    end
  end
end
