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
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Migrator
  alias Astarte.Housekeeping.Realms.Realm, as: HKRealm

  require Logger

  @default_replication_factor 1

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
      if opts[:async] do
        {:ok, _pid} =
          Task.start(fn ->
            do_create_realm(
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
        do_create_realm(
          realm_name,
          keyspace_name,
          public_key_pem,
          replication_map_str,
          device_limit,
          max_retention
        )
      end
    end
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
         :ok <- create_realm_kv_store(keyspace_name),
         :ok <- create_names_table(keyspace_name),
         :ok <- create_capabilities_type(keyspace_name),
         :ok <- create_devices_table(keyspace_name),
         :ok <- create_endpoints_table(keyspace_name),
         :ok <- create_interfaces_table(keyspace_name),
         :ok <- create_individual_properties_table(keyspace_name),
         :ok <- create_simple_triggers_table(keyspace_name),
         :ok <- create_grouped_devices_table(keyspace_name),
         :ok <- create_deletion_in_progress_table(keyspace_name),
         :ok <- create_ownership_vouchers_table(keyspace_name),
         :ok <- create_to2_sessions_table(keyspace_name),
         :ok <- insert_realm_public_key(keyspace_name, public_key_pem),
         :ok <- insert_realm_astarte_schema_version(keyspace_name),
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
      Enum.reduce_while(datacenter_replication_factors, :ok, fn
        {datacenter, replication_factor}, _acc ->
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
      end)
    end
  end

  defp build_replication_map_str(replication_factor)
       when is_integer(replication_factor) and replication_factor > 0 do
    with :ok <- check_replication(replication_factor) do
      replication_map_str =
        "{'class': 'SimpleStrategy', 'replication_factor': #{replication_factor}}"

      {:ok, replication_map_str}
    end
  end

  defp build_replication_map_str(datacenter_replication_factors)
       when is_map(datacenter_replication_factors) do
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
    query = """
    CREATE KEYSPACE #{keyspace_name}
    WITH replication = #{replication_map_str}
    AND durable_writes = true;
    """

    case CSystem.execute_schema_change(query) do
      {:ok, %{rows: nil, num_rows: 1}} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warning("Cannot create keyspace: #{inspect(reason)}.",
            tag: "build_keyspace_error",
            realm: keyspace_name
          )

        {:error, reason}
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

  defp insert_realm_astarte_schema_version(keyspace_name) do
    consistency = Consistency.domain_model(:write)

    opts = [
      consistency: consistency,
      prefix: keyspace_name
    ]

    kv_store_map = %{
      group: "astarte",
      key: "schema_version",
      value: Migrator.latest_realm_schema_version(),
      value_type: :big_integer
    }

    KvStore.insert(kv_store_map, opts)
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

  defp get_local_datacenter do
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

  defp create_deletion_in_progress_table(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.deletion_in_progress (
      device_id uuid,
      vmq_ack boolean,
      dup_start_ack boolean,
      dup_end_ack boolean,
      groups set<text>,

      PRIMARY KEY (device_id)
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp create_ownership_vouchers_table(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.ownership_vouchers (
      private_key blob,
      voucher_data blob,
      device_id uuid,
      PRIMARY KEY (device_id, voucher_data)
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp create_to2_sessions_table(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.to2_sessions (
      session_key blob,
      device_id uuid,
      device_public_key blob,
      prove_ov_nonce blob,
      kex_suite_name ascii,
      cipher_suite_name ascii,
      owner_random blob,
      secret blob,
      sevk blob,
      svk blob,
      sek blob,
      PRIMARY KEY (session_key)
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp create_grouped_devices_table(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.grouped_devices (
      group_name varchar,
      insertion_uuid timeuuid,
      device_id uuid,

      PRIMARY KEY ((group_name), insertion_uuid, device_id)
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp create_individual_properties_table(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.individual_properties (
      device_id uuid,
      interface_id uuid,
      endpoint_id uuid,
      path varchar,
      reception_timestamp timestamp,
      reception_timestamp_submillis smallint,
      double_value double,
      integer_value int,
      boolean_value boolean,
      longinteger_value bigint,
      string_value varchar,
      binaryblob_value blob,
      datetime_value timestamp,
      doublearray_value list<double>,
      integerarray_value list<int>,
      booleanarray_value list<boolean>,
      longintegerarray_value list<bigint>,
      stringarray_value list<varchar>,
      binaryblobarray_value list<blob>,
      datetimearray_value list<timestamp>,

      PRIMARY KEY((device_id, interface_id), endpoint_id, path)
    )
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp create_simple_triggers_table(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.simple_triggers (
      object_id uuid,
      object_type int,
      parent_trigger_id uuid,
      simple_trigger_id uuid,
      trigger_data blob,
      trigger_target blob,

      PRIMARY KEY ((object_id, object_type), parent_trigger_id, simple_trigger_id)
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp create_names_table(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.names (
      object_name varchar,
      object_type int,
      object_uuid uuid,

      PRIMARY KEY ((object_name), object_type)
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp create_capabilities_type(keyspace_name) do
    query = """
    CREATE TYPE #{keyspace_name}.capabilities (
      purge_properties_compression_format int
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp create_devices_table(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.devices (
      device_id uuid,
      aliases map<ascii, varchar>,
      introspection map<ascii, int>,
      introspection_minor map<ascii, int>,
      old_introspection map<frozen<tuple<ascii, int>>, int>,
      protocol_revision int,
      first_registration timestamp,
      credentials_secret ascii,
      inhibit_credentials_request boolean,
      cert_serial ascii,
      cert_aki ascii,
      first_credentials_request timestamp,
      last_connection timestamp,
      last_disconnection timestamp,
      connected boolean,
      pending_empty_cache boolean,
      total_received_msgs bigint,
      total_received_bytes bigint,
      exchanged_bytes_by_interface map<frozen<tuple<ascii, int>>, bigint>,
      exchanged_msgs_by_interface map<frozen<tuple<ascii, int>>, bigint>,
      last_credentials_request_ip inet,
      last_seen_ip inet,
      attributes map<varchar, varchar>,
      groups map<varchar, timeuuid>,
      capabilities capabilities,

      PRIMARY KEY (device_id)
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp create_endpoints_table(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.endpoints (
      interface_id uuid,
      endpoint_id uuid,
      interface_name ascii,
      interface_major_version int,
      interface_minor_version int,
      interface_type int,
      endpoint ascii,
      value_type int,
      reliability int,
      retention int,
      expiry int,
      database_retention_ttl int,
      database_retention_policy int,
      allow_unset boolean,
      explicit_timestamp boolean,
      description varchar,
      doc varchar,

      PRIMARY KEY ((interface_id), endpoint_id)
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp create_realm_kv_store(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
    """

    case CSystem.execute_schema_change(query) do
      {:ok, %{rows: nil, num_rows: 1}} ->
        :ok

      {:error, reason} ->
        Logger.warning("Cannot create kv_store: #{inspect(reason)}.",
          tag: "build_kv_store_error",
          realm: keyspace_name
        )

        {:error, reason}
    end
  end

  defp create_interfaces_table(keyspace_name) do
    query = """
    CREATE TABLE #{keyspace_name}.interfaces (
      name ascii,
      major_version int,
      minor_version int,
      interface_id uuid,
      storage_type int,
      storage ascii,
      type int,
      ownership int,
      aggregation int,
      automaton_transitions blob,
      automaton_accepting_states blob,
      description varchar,
      doc varchar,

      PRIMARY KEY (name, major_version)
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
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
    with :ok <- delete_realm_keyspace(keyspace_name),
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

    case Repo.fetch_one(query, consistency: consistency) do
      {:error, :not_found} ->
        :ok

      _ ->
        Logger.warning("Realm #{keyspace_name} still has connected devices.",
          tag: "connected_devices_present"
        )

        {:error, :connected_devices_present}
    end
  end

  defp delete_realm_keyspace(keyspace_name) do
    query = """
    DROP KEYSPACE #{keyspace_name}
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
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

  def initialize_database do
    with :ok <- create_astarte_keyspace(),
         :ok <- create_realms_table(),
         :ok <- create_astarte_kv_store(),
         :ok <- insert_astarte_schema_version() do
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

  defp create_astarte_keyspace do
    consistency = Consistency.domain_model(:write)

    replication =
      case Config.astarte_keyspace_replication_strategy!() do
        :simple_strategy -> Config.astarte_keyspace_replication_factor!()
        :network_topology_strategy -> Config.astarte_keyspace_network_replication_map!()
      end

    with {:ok, replication_map_str} <- build_replication_map_str(replication),
         query = """
         CREATE KEYSPACE #{Realm.astarte_keyspace_name()}
         WITH replication = #{replication_map_str}
         AND durable_writes = true;
         """,
         {:ok, %{rows: nil, num_rows: 1}} <-
           Repo.query(query, [], consistency: consistency) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("Cannot create Astarte Keyspace: #{inspect(reason)}.",
          tag: "astarte_keyspace_creation_failed"
        )

        {:error, reason}
    end
  end

  defp create_realms_table do
    query = """
    CREATE TABLE #{Realm.astarte_keyspace_name()}.realms (
      realm_name varchar,
      device_registration_limit bigint,
      PRIMARY KEY (realm_name)
    );
    """

    consistency = Consistency.domain_model(:write)

    with {:ok, %{rows: nil, num_rows: 1}} <-
           Repo.query(query, [], consistency: consistency) do
      :ok
    end
  end

  defp create_astarte_kv_store do
    query = """
    CREATE TABLE #{Realm.astarte_keyspace_name()}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
    """

    consistency = Consistency.domain_model(:write)

    with {:ok, %{rows: nil, num_rows: 1}} <-
           Repo.query(query, [], consistency: consistency) do
      :ok
    end
  end

  defp insert_astarte_schema_version do
    keyspace_name = Realm.astarte_keyspace_name()

    consistency = Consistency.domain_model(:write)

    opts = [
      consistency: consistency,
      prefix: keyspace_name
    ]

    kv_store_map = %{
      group: "astarte",
      key: "schema_version",
      value: Migrator.latest_astarte_schema_version(),
      value_type: :big_integer
    }

    KvStore.insert(kv_store_map, opts)
  end

  def astarte_keyspace_existing? do
    keyspace_name = Realm.astarte_keyspace_name()

    query =
      from k in "system_schema.keyspaces",
        where: k.keyspace_name == ^keyspace_name,
        select: count()

    consistency = Consistency.domain_model(:read)

    with {:ok, count} <- Repo.safe_fetch_one(query, consistency: consistency) do
      {:ok, count > 0}
    end
  end
end
