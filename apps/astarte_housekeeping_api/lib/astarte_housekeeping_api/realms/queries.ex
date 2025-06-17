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
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Housekeeping.API.Realms.Realm, as: HKRealm

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
    with :ok <- verify_realm_exists(realm_name),
         {:ok, public_key} <- fetch_public_key(keyspace_name),
         {:ok, replication_map} <- fetch_realm_replication(keyspace_name),
         {:ok, device_registration_limit} <- fetch_device_registration_limit(realm_name) do
      max_retention = get_datastream_maximum_storage_retention(keyspace_name)

      {replication_class, replication_factor, datacenter_replication_factors} =
        replication_values(replication_map)

      realm = %HKRealm{
        realm_name: realm_name,
        jwt_public_key_pem: public_key,
        replication_class: replication_class,
        replication_factor: replication_factor,
        datacenter_replication_factors: datacenter_replication_factors,
        device_registration_limit: device_registration_limit,
        datastream_maximum_storage_retention: max_retention
      }

      {:ok, realm}
    end
  end

  def set_device_registration_limit(realm_name, device_registration_limit) do
    opts = [prefix: Realm.astarte_keyspace_name(), consistency: Consistency.domain_model(:write)]

    from(Realm, where: [realm_name: ^realm_name])
    |> Repo.update_all([set: [device_registration_limit: device_registration_limit]], opts)

    :ok
  end

  def delete_device_registration_limit(realm_name) do
    keyspace = Realm.astarte_keyspace_name()

    query =
      from Realm,
        where: [realm_name: ^realm_name]

    opts = [consistency: Consistency.domain_model(:write), prefix: keyspace]

    # nil inserts a tombstone
    # https://hexdocs.pm/xandra/Xandra.html#module-values
    Repo.update_all(query, [set: [device_registration_limit: nil]], opts)

    :ok
  end

  def set_datastream_maximum_storage_retention(realm_name, retention) do
    opts = [
      consistency: Consistency.domain_model(:write),
      prefix: Realm.keyspace_name(realm_name)
    ]

    kv_store = %{
      group: "realm_config",
      key: "datastream_maximum_storage_retention",
      value: retention,
      value_type: :integer
    }

    with {:error, xandra_error} <- KvStore.insert(kv_store, opts) do
      raise xandra_error
    end
  end

  def delete_datastream_maximum_storage_retention(realm_name) do
    opts = [
      consistency: Consistency.domain_model(:write),
      prefix: Realm.keyspace_name(realm_name)
    ]

    from(KvStore, where: [group: "realm_config", key: "datastream_maximum_storage_retention"])
    |> Repo.delete_all(opts)

    :ok
  end

  def update_public_key(realm_name, jwt_public_key_pem) do
    opts = [
      consistency: Consistency.domain_model(:write),
      prefix: Realm.keyspace_name(realm_name)
    ]

    kv_store = %{
      group: "auth",
      key: "jwt_public_key_pem",
      value: jwt_public_key_pem,
      value_type: :string
    }

    with {:error, xandra_error} <- KvStore.insert(kv_store, opts) do
      raise xandra_error
    end
  end

  defp replication_values(
         %{
           "class" => "org.apache.cassandra.locator.SimpleStrategy",
           "replication_factor" => replication_factor_string
         } = _replication_map
       ) do
    {replication_factor, ""} = Integer.parse(replication_factor_string)

    {"SimpleStrategy", replication_factor, nil}
  end

  defp replication_values(
         %{"class" => "org.apache.cassandra.locator.NetworkTopologyStrategy"} = replication_map
       ) do
    datacenter_map =
      replication_map
      |> Map.delete("class")
      |> Map.new(fn {datacenter, replication_factor_string} ->
        {replication_factor, ""} = Integer.parse(replication_factor_string)
        {datacenter, replication_factor}
      end)

    {"NetworkTopologyStrategy", nil, datacenter_map}
  end

  defp verify_realm_exists(realm_name) do
    case is_realm_existing(realm_name) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :realm_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_public_key(keyspace) do
    consistency = Consistency.domain_model(:read)

    KvStore.fetch_value("auth", "jwt_public_key_pem", :string,
      error: :public_key_not_found,
      consistency: consistency,
      prefix: keyspace
    )
  end

  defp fetch_realm_replication(keyspace) do
    opts = [consistency: Consistency.domain_model(:read), error: :realm_replication_not_found]

    from(k in "keyspaces", prefix: "system_schema", select: k.replication, limit: 1)
    |> Repo.fetch_by(%{keyspace_name: keyspace}, opts)
  end

  defp fetch_device_registration_limit(realm_name) do
    astarte_keyspace = Realm.astarte_keyspace_name()

    opts = [
      consistency: Consistency.domain_model(:read),
      error: :realm_device_registration_limit_not_found
    ]

    from(r in Realm, prefix: ^astarte_keyspace, select: r.device_registration_limit)
    |> Repo.fetch(realm_name, opts)
  end

  defp get_datastream_maximum_storage_retention(keyspace) do
    opts = [consistency: Consistency.domain_model(:read), prefix: keyspace]

    case KvStore.fetch_value(
           "realm_config",
           "datastream_maximum_storage_retention",
           :integer,
           opts
         ) do
      {:ok, value} -> value
      {:error, :not_found} -> nil
    end
  end
end
