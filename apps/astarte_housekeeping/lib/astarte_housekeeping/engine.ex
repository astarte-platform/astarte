#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

    Queries.create_realm(client, realm, public_key_pem, replication_factor, opts)
  end

  def get_health() do
    with {:ok, client} <- DatabaseClient.new(),
         :ok <- Queries.check_astarte_health(client, :each_quorum) do
      {:ok, %{status: :ready}}
    else
      {:error, :health_check_bad} ->
        with {:ok, client} <- DatabaseClient.new(),
             :ok <- Queries.check_astarte_health(client, :one) do
          {:ok, %{status: :degraded}}
        else
          {:error, :health_check_bad} ->
            {:ok, %{status: :bad}}

          {:error, :database_connection_error} ->
            {:ok, %{status: :error}}
        end

      {:error, :database_connection_error} ->
        {:ok, %{status: :error}}
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
