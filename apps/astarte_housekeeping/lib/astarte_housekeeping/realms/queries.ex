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

defmodule Astarte.Housekeeping.Realms.Queries do
  @moduledoc false
  import Ecto.Query

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.CSystem
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Realms.Realm, as: HKRealm

  require Logger

  @default_replication_factor {:simple_strategy, 1}

  def realm_existing?(realm_name) do
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
          tag: "realm_existing_error",
          realm: realm_name
        )

        {:error, reason}
    end
  end

  def fetch_keyspace_replication do
    astarte_keyspace = Realm.astarte_keyspace_name()
    consistency = Consistency.domain_model(:read)

    result =
      KvStore.fetch_value("astarte", "db_default_replication", :binary,
        error: :replication_not_found,
        consistency: consistency,
        prefix: astarte_keyspace
      )

    case result do
      {:ok, binary_replication} ->
        try do
          {:ok, :erlang.binary_to_term(binary_replication)}
        rescue
          _ ->
            Logger.error("Failed to deserialize replication data from KvStore",
              tag: "corrupted_replication_data"
            )

            {:error, :corrupted_replication_data}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_realm(realm_name) do
    keyspace_name = Realm.keyspace_name(realm_name)
    do_get_realm(realm_name, keyspace_name)
  rescue
    ArgumentError ->
      _ = Logger.warning("Invalid realm name.", tag: "invalid_realm_name", realm: realm_name)

      {:error, :realm_not_allowed}
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

    query =
      from Realm,
        where: [realm_name: ^realm_name]

    Repo.update_all(query, [set: [device_registration_limit: device_registration_limit]], opts)

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

    query =
      from KvStore,
        where: [group: "realm_config", key: "datastream_maximum_storage_retention"]

    Repo.delete_all(query, opts)

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

  def create_realm(
        realm_name,
        public_key_pem,
        nil = _replication_factor,
        device_limit,
        max_retention,
        opts
      ) do
    create_realm(
      realm_name,
      public_key_pem,
      @default_replication_factor,
      device_limit,
      max_retention,
      opts
    )
  end

  def create_realm(realm_name, public_key_pem, replication, device_limit, max_retention, opts) do
    keyspace_name = Realm.keyspace_name(realm_name)

    with {:ok, replication_map_str} <- build_replication_map_str(replication) do
      execute_realm_creation(
        realm_name,
        keyspace_name,
        public_key_pem,
        replication_map_str,
        device_limit,
        max_retention,
        opts
      )
    end
  end

  defp execute_realm_creation(
         realm_name,
         keyspace_name,
         public_key_pem,
         replication_map_str,
         device_limit,
         max_retention,
         opts
       ) do
    if opts[:async] do
      {:ok, _pid} =
        Task.start(fn ->
          do_execute_realm_creation(
            realm_name,
            keyspace_name,
            public_key_pem,
            replication_map_str,
            device_limit,
            max_retention
          )
        end)

      {:ok, :started}
    else
      do_execute_realm_creation(
        realm_name,
        keyspace_name,
        public_key_pem,
        replication_map_str,
        device_limit,
        max_retention
      )
    end
  end

  defp do_execute_realm_creation(
         realm_name,
         keyspace_name,
         public_key_pem,
         replication_map_str,
         device_limit,
         max_retention
       ) do
    Repo.checkout(fn ->
      do_create_realm(
        realm_name,
        keyspace_name,
        public_key_pem,
        replication_map_str,
        device_limit,
        max_retention
      )
    end)
  end

  defp do_create_realm(
         realm_name,
         keyspace_name,
         public_key_pem,
         replication_map_str,
         device_limit,
         max_retention
       ) do
    with :ok <- create_realm_keyspace(keyspace_name, replication_map_str),
         :ok <- Database.migrate_realm(realm_name),
         :ok <- insert_realm_public_key(keyspace_name, public_key_pem),
         :ok <- insert_realm(realm_name, device_limit),
         :ok <- insert_datastream_max_retention(keyspace_name, max_retention) do
      :ok
    else
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
          Logger.warning("Cannot create realm: #{inspect(reason)}.",
            tag: "realm_creation_failed",
            realm: realm_name
          )

        {:error, reason}
    end
  end

  defp check_replication(1) do
    :ok
  end

  # If replication factor is an integer, we're using SimpleStrategy
  # Check that the replication factor is <= the number of nodes in the same datacenter
  defp check_replication(replication_factor)
       when is_integer(replication_factor) and replication_factor > 1 do
    with {:ok, local_datacenter} <- get_local_datacenter() do
      check_replication_for_datacenter(local_datacenter, replication_factor, local: true)
    end
  end

  defp check_replication(datacenter_replication_factors)
       when is_map(datacenter_replication_factors) do
    with {:ok, local_datacenter} <- get_local_datacenter() do
      Enum.reduce_while(
        datacenter_replication_factors,
        :ok,
        &check_datacenter_replication(&1, &2, local_datacenter)
      )
    end
  end

  defp check_datacenter_replication({datacenter, replication_factor}, _acc, local_datacenter) do
    opts =
      if datacenter == local_datacenter do
        [local: true]
      else
        []
      end

    case check_replication_for_datacenter(datacenter, replication_factor, opts) do
      :ok -> {:cont, :ok}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp build_replication_map_str({:simple_strategy, replication_factor}) do
    with :ok <- check_replication(replication_factor) do
      replication_map_str =
        "{'class': 'SimpleStrategy', 'replication_factor': #{replication_factor}}"

      {:ok, replication_map_str}
    end
  end

  defp build_replication_map_str({:network_topology_strategy, datacenter_replication_factors}) do
    with :ok <- check_replication(datacenter_replication_factors) do
      datacenter_replications_str =
        Enum.map_join(datacenter_replication_factors, ",", fn {datacenter, replication_factor} ->
          "'#{datacenter}': #{replication_factor}"
        end)

      replication_map_str = "{'class': 'NetworkTopologyStrategy', #{datacenter_replications_str}}"

      {:ok, replication_map_str}
    end
  end

  defp build_replication_map_str(_invalid_replication) do
    {:error, :invalid_replication}
  end

  defp create_realm_keyspace(keyspace_name, replication_map_str) do
    base_query = """
    CREATE KEYSPACE #{keyspace_name}
    WITH replication = #{replication_map_str}
    AND durable_writes = true
    """

    tablets_query = base_query <> " AND tablets = { 'enabled': false }"

    case CSystem.execute_schema_change(tablets_query) do
      {:ok, %{rows: nil, num_rows: 1}} ->
        :ok

      {:ok, res} ->
        "Unexpected ok result from database while creating astarte keyspace: #{inspect(res)}"
        |> Logger.warning()

        {:error, :astarte_keyspace_creation_failed}

      {:error, %Xandra.Error{reason: :already_exists}} ->
        "Tried to create already existing realm"
        |> Logger.warning(realm: keyspace_name)

        {:error, :conflicting_realm_name}

      {:error, _reason} ->
        case CSystem.execute_schema_change(base_query) do
          {:ok, %{rows: nil, num_rows: 1}} ->
            :ok

          {:ok, res} ->
            "Unexpected ok result from database while creating astarte keyspace: #{inspect(res)}"
            |> Logger.warning()

            {:error, :astarte_keyspace_creation_failed}

          {:error, %Xandra.Error{reason: :already_exists}} ->
            "Tried to create already existing realm"
            |> Logger.warning(realm: keyspace_name)

            {:error, :conflicting_realm_name}

          {:error, reason} ->
            _ =
              Logger.warning("Cannot create keyspace: #{inspect(reason)}.",
                tag: "build_keyspace_error",
                realm: keyspace_name
              )

            {:error, reason}
        end
    end
  end

  # ScyllaDB considers TTL=0 as unset, see
  # https://opensource.docs.scylladb.com/stable/cql/time-to-live.html#notes
  defp insert_datastream_max_retention(_keyspace_name, 0) do
    :ok
  end

  # Apparently, before when the field was nil, it was encoded as zero (not optional on protobuff),
  # so treat it the same as zero
  defp insert_datastream_max_retention(_keyspace_name, nil) do
    :ok
  end

  defp insert_datastream_max_retention(keyspace_name, max_retention) do
    consistency = Consistency.domain_model(:write)

    opts = [
      consistency: consistency,
      prefix: keyspace_name
    ]

    kv_store_map = %{
      group: "realm_config",
      key: "datastream_maximum_storage_retention",
      value: max_retention,
      value_type: :integer
    }

    KvStore.insert(kv_store_map, opts)
  end

  defp insert_realm(realm_name, device_limit) do
    keyspace_name = Realm.astarte_keyspace_name()

    device_registration_limit = if device_limit == 0, do: nil, else: device_limit

    realm_attrs = %Realm{
      realm_name: realm_name,
      device_registration_limit: device_registration_limit
    }

    consistency = Consistency.domain_model(:write)

    opts = [
      consistency: consistency,
      prefix: keyspace_name
    ]

    case Repo.insert(realm_attrs, opts) do
      {:ok, _realm} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_realm_public_key(keyspace_name, public_key_pem) do
    consistency = Consistency.domain_model(:write)

    opts = [
      consistency: consistency,
      prefix: keyspace_name
    ]

    kv_store_map = %{
      group: "auth",
      key: "jwt_public_key_pem",
      value: public_key_pem,
      value_type: :string
    }

    KvStore.insert(kv_store_map, opts)
  end

  @doc false
  def get_local_datacenter do
    query =
      from sl in "system.local",
        select: sl.data_center

    opts = [consistency: Consistency.domain_model(:read)]

    case Repo.safe_fetch_one(query, opts) do
      {:ok, datacenter} ->
        {:ok, datacenter}

      {:error, :not_found} ->
        Logger.error(
          "Empty dataset while getting local datacenter, something is really wrong.",
          tag: "get_local_datacenter_error"
        )

        {:error, :local_datacenter_not_found}

      {:error, error} ->
        Logger.error("Error while getting local datacenter: #{inspect(error)}.",
          tag: "get_local_datacenter_error"
        )

        {:error, error}
    end
  end

  defp check_replication_for_datacenter(datacenter, replication_factor, opts) do
    query =
      from sp in "system.peers",
        hints: ["ALLOW FILTERING"],
        where: sp.data_center == ^datacenter,
        select: count()

    case Repo.safe_fetch_one(query, opts) do
      {:ok, dc_node_count} ->
        # If we're querying the datacenter of the local node, add 1 (itself) to the count
        actual_node_count =
          if opts[:local] do
            dc_node_count + 1
          else
            dc_node_count
          end

        if replication_factor <= actual_node_count do
          :ok
        else
          Logger.warning(
            "Trying to set replication_factor #{replication_factor} " <>
              "in datacenter #{datacenter} that has #{actual_node_count} nodes.",
            tag: "invalid_replication_factor",
            datacenter: datacenter,
            replication_factor: replication_factor
          )

          error_message =
            "replication_factor #{replication_factor} is >= #{actual_node_count} nodes " <>
              "in datacenter #{datacenter}"

          {:error, {:invalid_replication, error_message}}
        end

      {:error, :not_found} ->
        Logger.warning("Cannot retrieve node count for datacenter #{datacenter}.",
          tag: "datacenter_not_found",
          datacenter: datacenter
        )

        {:error, :datacenter_not_found}

      {:error, reason} ->
        Logger.warning(
          "Database error while checking replication for datacenter #{datacenter}: #{inspect(reason)}.",
          tag: "database_error",
          datacenter: datacenter
        )

        {:error, reason}
    end
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

  defp replication_values(
         %{
           "class" => "org.apache.cassandra.locator.SimpleStrategy",
           "replication_factor" => replication_factor_string
         } = _replication_map
       ) do
    {replication_factor, ""} = Integer.parse(replication_factor_string)

    {"SimpleStrategy", replication_factor, nil}
  end

  defp verify_realm_exists(realm_name) do
    case realm_existing?(realm_name) do
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

    query =
      from k in "keyspaces",
        prefix: "system_schema",
        select: k.replication,
        limit: 1

    Repo.fetch_by(query, %{keyspace_name: keyspace}, opts)
  end

  defp fetch_device_registration_limit(realm_name) do
    astarte_keyspace = Realm.astarte_keyspace_name()

    opts = [
      consistency: Consistency.domain_model(:read),
      error: :realm_device_registration_limit_not_found
    ]

    query =
      from r in Realm,
        prefix: ^astarte_keyspace,
        select: r.device_registration_limit

    Repo.fetch(query, realm_name, opts)
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

  def list_realms do
    keyspace_name = Realm.astarte_keyspace_name()

    query =
      from r in Realm,
        prefix: ^keyspace_name,
        select: r.realm_name

    consistency = Consistency.domain_model(:read)

    case Repo.fetch_all(query, consistency: consistency) do
      {:ok, realm_names} ->
        realms =
          Enum.map(realm_names, fn realm_name ->
            %HKRealm{realm_name: realm_name}
          end)

        {:ok, realms}

      {:error, reason} ->
        Logger.warning("Failed to list realms: #{inspect(reason)}.",
          tag: "list_realms_error"
        )

        {:error, reason}
    end
  end

  def delete_realm(realm_name, opts \\ []) do
    if Config.enable_realm_deletion!() do
      Logger.info("Deleting realm", tag: "delete_realm", realm: realm_name)
      do_delete_realm_with_options(realm_name, opts)
    else
      Logger.info("HOUSEKEEPING_ENABLE_REALM_DELETION is disabled, realm will not be deleted.",
        tag: "realm_deletion_disabled",
        realm: realm_name
      )

      {:error, :realm_deletion_disabled}
    end
  end

  defp do_delete_realm_with_options(realm_name, opts) do
    keyspace_name = Realm.keyspace_name(realm_name)

    if opts[:async] do
      {:ok, _pid} = Task.start(fn -> do_delete_realm(realm_name, keyspace_name) end)
      :ok
    else
      do_delete_realm(realm_name, keyspace_name)
    end
  end

  defp do_delete_realm(realm_name, keyspace_name) do
    with :ok <- verify_realm_deletion_preconditions(keyspace_name),
         :ok <- execute_realm_deletion(realm_name, keyspace_name) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.warning("Database connection error: #{inspect(err)}.",
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}

      {:error, reason} ->
        Logger.warning("Cannot delete realm: #{inspect(reason)}.",
          tag: "realm_deletion_failed",
          realm: realm_name
        )

        {:error, reason}
    end
  end

  defp verify_realm_deletion_preconditions(keyspace_name) do
    case check_no_connected_devices(keyspace_name) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Realm deletion preconditions are not satisfied: #{inspect(reason)}.",
          tag: "realm_deletion_preconditions_rejected",
          realm: keyspace_name
        )

        {:error, reason}
    end
  end

  defp execute_realm_deletion(realm_name, keyspace_name) do
    with :ok <- ensure_realm_keyspace_deletion(keyspace_name),
         :ok <- remove_realm(realm_name) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("Cannot delete realm: #{inspect(reason)}.",
          tag: "realm_deletion_failed",
          realm: realm_name
        )

        {:error, reason}
    end
  end

  defp check_no_connected_devices(keyspace_name) do
    query =
      from d in Device,
        hints: ["ALLOW FILTERING"],
        prefix: ^keyspace_name,
        where: d.connected == true,
        limit: 1

    consistency = Consistency.device_info(:read)

    case Repo.safe_fetch_one(query, consistency: consistency) do
      {:error, :not_found} ->
        :ok

      {:error, :realm_not_found} ->
        :ok

      _ ->
        Logger.warning("Realm #{keyspace_name} still has connected devices.",
          tag: "connected_devices_present"
        )

        {:error, :connected_devices_present}
    end
  end

  defp ensure_realm_keyspace_deletion(keyspace_name) do
    query = """
    DROP KEYSPACE IF EXISTS #{keyspace_name}
    """

    with {:ok, _} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp remove_realm(realm_name) do
    keyspace_name = Realm.astarte_keyspace_name()

    query =
      from r in Realm,
        prefix: ^keyspace_name,
        where: r.realm_name == ^realm_name

    consistency = Consistency.domain_model(:write)

    Repo.delete_all(query, consistency: consistency)

    :ok
  end

  def initialize_database(default_replication \\ {:simple_strategy, 1}) do
    Logger.info("Starting Astarte keyspace initialization")

    with :ok <- create_astarte_keyspace(default_replication),
         :ok <- Database.migrate_astarte() do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        Logger.error(
          "Database error while initializing database: #{inspect(err)}. ASTARTE WILL NOT WORK.",
          tag: "init_database_error"
        )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.error(
          "Database connection error while initializing database: #{inspect(err)}. ASTARTE WILL NOT WORK.",
          tag: "init_database_connection_error"
        )

        {:error, :database_connection_error}

      {:error, reason} ->
        Logger.error(
          "Error while initializing database: #{inspect(reason)}. ASTARTE WILL NOT WORK.",
          tag: "init_error"
        )

        {:error, reason}
    end
  end

  defp keyspace_replication_map({:simple_strategy, replication_factor}) do
    %{
      strategy: :simple,
      factor: replication_factor
    }
  end

  defp keyspace_replication_map({:network_topology_strategy, network_topology}) do
    %{
      strategy: :network_topology,
      dc_factors: network_topology
    }
  end

  def save_keyspace_replication(replication) do
    opts = [
      consistency: Consistency.domain_model(:write),
      prefix: Realm.astarte_keyspace_name()
    ]

    replication = replication |> keyspace_replication_map() |> :erlang.term_to_binary()

    kv_store = %{
      group: "astarte",
      key: "db_default_replication",
      value: replication,
      value_type: :binary
    }

    KvStore.insert(kv_store, opts)
  end

  defp create_astarte_keyspace(default_replication) do
    keyspace = Realm.astarte_keyspace_name()
    consistency = Consistency.domain_model(:write)
    replication = astarte_keyspace_replication(default_replication)

    with {:ok, replication_map_str} <- build_replication_map_str(replication),
         :ok <- do_create_astarte_keyspace(keyspace, replication_map_str, consistency) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("Cannot create Astarte Keyspace: #{inspect(reason)}.",
          tag: "astarte_keyspace_creation_failed"
        )

        {:error, reason}
    end
  end

  defp astarte_keyspace_replication(default_replication) do
    case Config.astarte_keyspace_replication_strategy!() do
      :simple_strategy ->
        {:simple_strategy, Config.astarte_keyspace_replication_factor!()}

      :network_topology_strategy ->
        {:network_topology_strategy, Config.astarte_keyspace_network_replication_map!()}

      nil ->
        # No explicit replication has been configured, so the replication
        # map is derived from the current ScyllaDB network topology
        default_replication
    end
  end

  def fetch_network_topology do
    with {:ok, local_datacenter} <- get_local_datacenter(),
         {:ok, peer_datacenters} <- fetch_peer_datacenters() do
      peer_counts = Enum.frequencies(peer_datacenters)

      # `system.peers` does not include the local node, so 1 is added to the local
      # datacenter count to account for it (same as in
      # `check_replication_for_datacenter/3`).
      local_dc_node_count = Map.get(peer_counts, local_datacenter, 0) + 1
      topology = Map.put(peer_counts, local_datacenter, local_dc_node_count)

      {:ok, topology}
    end
  end

  defp fetch_peer_datacenters do
    query =
      from sp in "system.peers",
        select: sp.data_center

    opts = [consistency: Consistency.domain_model(:read)]

    case Repo.fetch_all(query, opts) do
      {:ok, datacenters} ->
        {:ok, datacenters}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_create_astarte_keyspace(keyspace, replication, consistency) do
    base_query = """
    CREATE KEYSPACE #{keyspace}
    WITH replication = #{replication}
    AND durable_writes = true
    """

    tablets_query = base_query <> " AND tablets = { 'enabled': false }"

    opts = [consistency: consistency]

    case Repo.query(tablets_query, [], opts) do
      {:ok, _} ->
        Logger.info("Astarte keyspace initialized")
        :ok

      {:error, %Xandra.Error{reason: :already_exists}} ->
        :ok

      _ ->
        case Repo.query(base_query, [], opts) do
          {:ok, _} ->
            Logger.info("Astarte keyspace initialized")
            :ok

          {:error, %Xandra.Error{reason: :already_exists}} ->
            :ok

          error ->
            error
        end
    end
  end
end
