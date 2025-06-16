#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Housekeeping.API.Realms.Queries do
  import Ecto.Query

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Housekeeping.API.Realms.Realm, as: HKRealm
  alias Astarte.Core.Realm, as: CoreRealm

  require Logger

  def is_realm_existing(realm_name) do
    keyspace_name = Realm.astarte_keyspace_name()

    query =
      from r in Realm,
        prefix: ^keyspace_name,
        where: r.realm_name == ^realm_name,
        select: count()

    consistency = Consistency.domain_model(:read)

    case Repo.safe_fetch_one(query, consistency: consistency) do
      {:ok, count} ->
        {:ok, count > 0}

      {:error, reason} ->
        Logger.warning("Cannot check if realm exists: #{inspect(reason)}.",
          tag: "is_realm_existing_error",
          realm: realm_name
        )

        {:error, reason}
    end
  end

  def get_realm(realm_name) do
    try do
      keyspace_name = Realm.keyspace_name(realm_name)
      do_get_realm(realm_name, keyspace_name)
    rescue
      ArgumentError ->
        _ = Logger.warning("Invalid realm name.", tag: "invalid_realm_name", realm: realm_name)

        {:error, :realm_not_allowed}
    end
  end

  defp do_get_realm(realm_name, keyspace_name) do
    Xandra.Cluster.run(:xandra, fn conn ->
      with {:ok, true} <- is_realm_existing(realm_name),
           {:ok, public_key} <- get_public_key(conn, keyspace_name),
           {:ok, replication_map} <- get_realm_replication(conn, keyspace_name),
           {:ok, device_registration_limit} <- get_device_registration_limit(conn, realm_name),
           {:ok, max_retention} <-
             get_datastream_maximum_storage_retention(conn, keyspace_name) do
        case replication_map do
          %{
            "class" => "org.apache.cassandra.locator.SimpleStrategy",
            "replication_factor" => replication_factor_string
          } ->
            {replication_factor, ""} = Integer.parse(replication_factor_string)

            {:ok,
             %HKRealm{
               realm_name: realm_name,
               jwt_public_key_pem: public_key,
               replication_class: "SimpleStrategy",
               replication_factor: replication_factor,
               device_registration_limit: device_registration_limit,
               datastream_maximum_storage_retention: max_retention
             }}

          %{"class" => "org.apache.cassandra.locator.NetworkTopologyStrategy"} ->
            datacenter_replication_factors =
              Enum.reduce(replication_map, %{}, fn
                {"class", _}, acc ->
                  acc

                {datacenter, replication_factor_string}, acc ->
                  {replication_factor, ""} = Integer.parse(replication_factor_string)
                  Map.put(acc, datacenter, replication_factor)
              end)

            {:ok,
             %HKRealm{
               realm_name: realm_name,
               jwt_public_key_pem: public_key,
               replication_class: "NetworkTopologyStrategy",
               datacenter_replication_factors: datacenter_replication_factors,
               device_registration_limit: device_registration_limit,
               datastream_maximum_storage_retention: max_retention
             }}
        end
      else
        # Returned by is_realm_existing
        {:ok, false} ->
          {:error, :realm_not_found}

        {:error, %Xandra.Error{} = err} ->
          _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
          {:error, :database_error}

        {:error, %Xandra.ConnectionError{} = err} ->
          _ =
            Logger.warning("Database connection error: #{inspect(err)}.",
              tag: "database_connection_error"
            )

          {:error, :database_connection_error}

        {:error, reason} ->
          _ =
            Logger.warning("Error while getting realm: #{inspect(reason)}.",
              tag: "get_realm_error",
              realm: realm_name
            )

          {:error, reason}
      end
    end)
  end

  defp get_public_key(conn, realm_name) do
    statement = """
    SELECT blobAsVarchar(value)
    FROM :realm_name.kv_store
    WHERE group='auth' AND key='jwt_public_key_pem';
    """

    consistency = Consistency.domain_model(:read)

    with :ok <- validate_realm_name(realm_name),
         query = String.replace(statement, ":realm_name", realm_name),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, query, %{}, consistency: consistency) do
      case Enum.fetch(page, 0) do
        {:ok, %{"system.blobasvarchar(value)" => public_key}} ->
          {:ok, public_key}

        :error ->
          {:error, :public_key_not_found}
      end
    else
      {:error, reason} ->
        _ =
          Logger.warning("Cannot get public key: #{inspect(reason)}.",
            tag: "get_public_key_error",
            realm: realm_name
          )

        {:error, reason}
    end
  end

  defp validate_realm_name(realm_name) do
    if CoreRealm.valid_name?(realm_name) do
      :ok
    else
      _ =
        Logger.warning("Invalid realm name.",
          tag: "invalid_realm_name",
          realm: realm_name
        )

      {:error, :realm_not_allowed}
    end
  end

  defp get_realm_replication(conn, realm_name) do
    query = """
    SELECT replication
    FROM system_schema.keyspaces
    WHERE keyspace_name=:realm_name
    """

    opts = [consistency: Consistency.domain_model(:read)]

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, page} <- Xandra.execute(conn, prepared, %{"realm_name" => realm_name}, opts) do
      case Enum.fetch(page, 0) do
        {:ok, %{"replication" => replication_map}} ->
          {:ok, replication_map}

        :error ->
          # Something really wrong here, but we still cover this
          _ =
            Logger.error("Cannot find realm replication.",
              tag: "realm_replication_not_found",
              realm: realm_name
            )

          {:error, :realm_replication_not_found}
      end
    end
  end

  defp get_device_registration_limit(conn, realm_name) do
    query = """
    SELECT device_registration_limit
    FROM #{Realm.astarte_keyspace_name()}.realms
    WHERE realm_name=:realm_name
    """

    opts = [consistency: Consistency.domain_model(:read)]

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, page} <- Xandra.execute(conn, prepared, %{"realm_name" => realm_name}, opts) do
      case Enum.fetch(page, 0) do
        {:ok, %{"device_registration_limit" => value}} ->
          {:ok, value}

        :error ->
          # Something really wrong here, but we still cover this
          _ =
            Logger.error("Cannot find realm device_registration_limit.",
              tag: "realm_device_registration_limit_not_found",
              realm: realm_name
            )

          {:error, :realm_device_registration_limit_not_found}
      end
    end
  end

  defp get_datastream_maximum_storage_retention(conn, realm_name) do
    statement = """
    SELECT blobAsInt(value)
    FROM :realm_name.kv_store
    WHERE group='realm_config' AND key='datastream_maximum_storage_retention'
    """

    opts = [consistency: Consistency.domain_model(:read)]

    # TODO change this once NoaccOS' PR is merged
    with :ok <- validate_realm_name(realm_name),
         query = String.replace(statement, ":realm_name", realm_name),
         {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, page} <- Xandra.execute(conn, prepared, %{}, opts) do
      case Enum.fetch(page, 0) do
        {:ok, %{"system.blobasint(value)" => value}} ->
          {:ok, value}

        :error ->
          {:ok, nil}
      end
    end
  end
end
