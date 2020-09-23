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

  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Queries

  def create_realm(realm, public_key_pem, replication_factor, opts \\ []) do
    _ =
      Logger.info(
        "Creating new realm.",
        tag: "create_realm",
        realm: realm,
        replication_factor: replication_factor
      )

    Queries.create_realm(realm, public_key_pem, replication_factor, opts)
  end

  def get_health do
    case Queries.check_astarte_health(:quorum) do
      :ok ->
        {:ok, %{status: :ready}}

      {:error, :health_check_bad} ->
        case Queries.check_astarte_health(:one) do
          :ok ->
            {:ok, %{status: :degraded}}

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
    Queries.get_realm(realm)
  end

  def delete_realm(realm, opts \\ []) do
    if Config.enable_realm_deletion!() do
      _ = Logger.info("Deleting realm", tag: "delete_realm", realm: realm)

      Queries.delete_realm(realm, opts)
    else
      _ =
        Logger.info("HOUSEKEEPING_ENABLE_REALM_DELETION is disabled, realm will not be deleted.",
          tag: "realm_deletion_disabled",
          realm: realm
        )

      {:error, :realm_deletion_disabled}
    end
  end

  def is_realm_existing(realm) do
    Queries.is_realm_existing(realm)
  end

  def list_realms do
    Queries.list_realms()
  end
end
