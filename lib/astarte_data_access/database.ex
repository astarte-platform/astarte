#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.DataAccess.Database do
  require Logger

  @spec connect() :: {:ok, :cqerl.client()} | {:error, atom}
  def connect() do
    with {:nodes, nodes} when is_list(nodes) <-
           {:nodes, Application.get_env(:cqerl, :cassandra_nodes)},
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
    with {:nodes, nodes} when is_list(nodes) <-
           {:nodes, Application.get_env(:cqerl, :cassandra_nodes)},
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
