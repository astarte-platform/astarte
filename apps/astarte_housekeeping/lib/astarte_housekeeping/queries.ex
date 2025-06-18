#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.Housekeeping.Queries do
  require Logger
  alias Astarte.Core.Realm
  alias Astarte.Core.CQLUtils
  alias Astarte.DataAccess.Consistency
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Migrator
  alias Astarte.DataAccess.CSystem

  @default_replication_factor 1

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
    with :ok <- validate_realm_name(realm_name),
         keyspace_name =
           CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!()),
         :ok <- Xandra.Cluster.run(:xandra, &check_replication(&1, replication)),
         {:ok, replication_map_str} <- build_replication_map_str(replication) do
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

        :ok
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

  def delete_realm(realm_name, opts \\ []) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    if opts[:async] do
      {:ok, _pid} = Task.start(fn -> do_delete_realm(realm_name, keyspace_name) end)

      :ok
    else
      do_delete_realm(realm_name, keyspace_name)
    end
  end

  defp build_replication_map_str(replication_factor)
       when is_integer(replication_factor) and replication_factor > 0 do
    replication_map_str =
      "{'class': 'SimpleStrategy', 'replication_factor': #{replication_factor}}"

    {:ok, replication_map_str}
  end

  defp build_replication_map_str(datacenter_replication_factors)
       when is_map(datacenter_replication_factors) do
    datacenter_replications_str =
      Enum.map(datacenter_replication_factors, fn {datacenter, replication_factor} ->
        "'#{datacenter}': #{replication_factor}"
      end)
      |> Enum.join(",")

    replication_map_str = "{'class': 'NetworkTopologyStrategy', #{datacenter_replications_str}}"

    {:ok, replication_map_str}
  end

  defp build_replication_map_str(_invalid_replication) do
    {:error, :invalid_replication}
  end

  defp validate_realm_name(realm_name) do
    if Realm.valid_name?(realm_name) do
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

  defp do_delete_realm(realm_name, keyspace_name) do
    Xandra.Cluster.run(:xandra, [timeout: 60_000], fn conn ->
      with :ok <- verify_realm_deletion_preconditions(conn, keyspace_name),
           :ok <- execute_realm_deletion(conn, realm_name, keyspace_name) do
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
            Logger.warning("Cannot delete realm: #{inspect(reason)}.",
              tag: "realm_deletion_failed",
              realm: realm_name
            )

          {:error, reason}
      end
    end)
  end

  defp verify_realm_deletion_preconditions(conn, keyspace_name) do
    with :ok <- check_no_connected_devices(conn, keyspace_name) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warning("Realm deletion preconditions are not satisfied: #{inspect(reason)}.",
            tag: "realm_deletion_preconditions_rejected",
            realm: keyspace_name
          )

        {:error, reason}
    end
  end

  defp execute_realm_deletion(conn, realm_name, keyspace_name) do
    with :ok <- delete_realm_keyspace(conn, keyspace_name),
         :ok <- remove_realm(conn, realm_name) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warning("Cannot delete realm: #{inspect(reason)}.",
            tag: "realm_deletion_failed",
            realm: realm_name
          )

        {:error, reason}
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
    Xandra.Cluster.run(:xandra, [timeout: 60_000], fn conn ->
      with :ok <- validate_realm_name(realm_name),
           :ok <- create_realm_keyspace(conn, keyspace_name, replication_map_str),
           {:ok, keyspace_conn} <- build_keyspace_conn(conn, keyspace_name),
           :ok <- create_realm_kv_store(keyspace_conn),
           :ok <- create_names_table(keyspace_conn),
           :ok <- create_devices_table(keyspace_conn),
           :ok <- create_endpoints_table(keyspace_conn),
           :ok <- create_interfaces_table(keyspace_conn),
           :ok <- create_individual_properties_table(keyspace_conn),
           :ok <- create_simple_triggers_table(keyspace_conn),
           :ok <- create_grouped_devices_table(keyspace_conn),
           :ok <- create_deletion_in_progress_table(keyspace_conn),
           :ok <- insert_realm_public_key(keyspace_conn, public_key_pem),
           :ok <- insert_realm_astarte_schema_version(keyspace_conn),
           :ok <- insert_realm(conn, realm_name, device_limit),
           :ok <- insert_datastream_max_retention(keyspace_conn, max_retention) do
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
    end)
  end

  defp build_keyspace_conn(conn, realm_name) do
    case validate_realm_name(realm_name) do
      :ok ->
        {:ok, {conn, realm_name}}

      {:error, reason} ->
        _ =
          Logger.warning("Cannot build realm conn: #{inspect(reason)}.",
            tag: "build_keyspace_conn_error",
            realm: realm_name
          )

        {:error, reason}
    end
  end

  defp check_no_connected_devices(conn, realm_name) do
    query = """
    SELECT * FROM #{realm_name}.devices WHERE connected = true LIMIT 1 ALLOW FILTERING;
    """

    consistency = Consistency.device_info(:read)

    with {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, query, %{}, consistency: consistency) do
      if Enum.empty?(page) do
        :ok
      else
        _ =
          Logger.warning("Realm #{realm_name} still has connected devices.",
            tag: "connected_devices_present"
          )

        {:error, :connected_devices_present}
      end
    end
  end

  defp delete_realm_keyspace(conn, realm_name) do
    query = """
    DROP KEYSPACE #{realm_name}
    """

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    end
  end

  defp create_realm_keyspace(conn, realm_name, replication_map_str) do
    query = """
    CREATE KEYSPACE #{realm_name}
    WITH replication = #{replication_map_str}
    AND durable_writes = true;
    """

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warning("Cannot create keyspace: #{inspect(reason)}.",
            tag: "build_keyspace_error",
            realm: realm_name
          )

        {:error, reason}
    end
  end

  defp create_realm_kv_store({conn, realm}) do
    query = """
    CREATE TABLE #{realm}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
    """

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warning("Cannot create kv_store: #{inspect(reason)}.",
            tag: "build_kv_store_error",
            realm: realm
          )

        {:error, reason}
    end
  end

  defp create_names_table({conn, realm}) do
    query = """
    CREATE TABLE #{realm}.names (
      object_name varchar,
      object_type int,
      object_uuid uuid,
      PRIMARY KEY ((object_name), object_type)
    );
    """

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    end
  end

  defp create_devices_table({conn, realm}) do
    query = """
    CREATE TABLE #{realm}.devices (
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

      groups map<text, timeuuid>,

      PRIMARY KEY (device_id)
    );
    """

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    end
  end

  defp create_endpoints_table({conn, realm}) do
    query = """
    CREATE TABLE #{realm}.endpoints (
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

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    end
  end

  defp create_interfaces_table({conn, realm}) do
    query = """
    CREATE TABLE #{realm}.interfaces (
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

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    end
  end

  defp create_individual_properties_table({conn, realm}) do
    query = """
    CREATE TABLE #{realm}.individual_properties (
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

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    end
  end

  defp create_simple_triggers_table({conn, realm}) do
    query = """
    CREATE TABLE #{realm}.simple_triggers (
      object_id uuid,
      object_type int,
      parent_trigger_id uuid,
      simple_trigger_id uuid,
      trigger_data blob,
      trigger_target blob,

      PRIMARY KEY ((object_id, object_type), parent_trigger_id, simple_trigger_id)
    );
    """

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    end
  end

  defp create_grouped_devices_table({conn, realm}) do
    query = """
    CREATE TABLE #{realm}.grouped_devices (
      group_name varchar,
      insertion_uuid timeuuid,
      device_id uuid,

      PRIMARY KEY ((group_name), insertion_uuid, device_id)
    );
    """

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    end
  end

  defp create_deletion_in_progress_table({conn, realm}) do
    query = """
    CREATE TABLE #{realm}.deletion_in_progress (
      device_id uuid,
      vmq_ack boolean,
      dup_start_ack boolean,
      dup_end_ack boolean,
      PRIMARY KEY (device_id)
    );
    """

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    end
  end

  defp insert_realm_public_key({conn, realm}, public_key_pem) do
    query = """
    INSERT INTO #{realm}.kv_store (group, key, value)
    VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:public_key_pem));
    """

    params = %{"public_key_pem" => public_key_pem}

    consistency = Consistency.domain_model(:write)

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, prepared, params, consistency: consistency) do
      :ok
    end
  end

  defp insert_realm_astarte_schema_version({conn, realm}) do
    query = """
    INSERT INTO #{realm}.kv_store
    (group, key, value)
    VALUES ('astarte', 'schema_version', bigintAsBlob(#{Migrator.latest_realm_schema_version()}));
    """

    consistency = Consistency.domain_model(:write)

    with {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, query, %{}, consistency: consistency) do
      :ok
    end
  end

  defp remove_realm(conn, realm_name) do
    # undecoded realm name
    query = """
    DELETE FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
    WHERE realm_name = :realm_name;
    """

    params = %{"realm_name" => realm_name}

    consistency = Consistency.domain_model(:write)

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, prepared, params, consistency: consistency) do
      :ok
    end
  end

  defp insert_realm(conn, realm_name, device_limit) do
    query = """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms (realm_name, device_registration_limit)
    VALUES (:realm_name, :device_registration_limit);
    """

    device_registration_limit = if device_limit == 0, do: nil, else: device_limit

    params = %{
      "realm_name" => realm_name,
      "device_registration_limit" => device_registration_limit
    }

    consistency = Consistency.domain_model(:write)

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, prepared, params, consistency: consistency) do
      :ok
    end
  end

  # ScyllaDB considers TTL=0 as unset, see
  # https://opensource.docs.scylladb.com/stable/cql/time-to-live.html#notes
  defp insert_datastream_max_retention(_conn_realm, 0) do
    :ok
  end

  defp insert_datastream_max_retention({conn, keyspace_name}, max_retention) do
    statement = """
    INSERT INTO :keyspace_name.kv_store (group, key, value)
    VALUES ('realm_config', 'datastream_maximum_storage_retention', intAsBlob(:max_retention));
    """

    params = %{
      "max_retention" => max_retention
    }

    # This is safe since we checked the realm name in the caller
    query = String.replace(statement, ":keyspace_name", keyspace_name)

    consistency = Consistency.domain_model(:write)

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, prepared, params, consistency: consistency) do
      :ok
    end
  end

  def initialize_database do
    Xandra.Cluster.run(:xandra, [timeout: 60_000], fn conn ->
      with :ok <- create_astarte_keyspace(conn),
           :ok <- create_realms_table(conn),
           :ok <- create_astarte_kv_store(conn),
           :ok <- insert_astarte_schema_version(conn) do
        :ok
      else
        {:error, %Xandra.Error{} = err} ->
          _ =
            Logger.error(
              "Database error while initializing database: #{inspect(err)}. ASTARTE WILL NOT WORK.",
              tag: "init_database_error"
            )

          {:error, :database_error}

        {:error, %Xandra.ConnectionError{} = err} ->
          _ =
            Logger.error(
              "Database connection error while initializing database: #{inspect(err)}. ASTARTE WILL NOT WORK.",
              tag: "init_database_connection_error"
            )

          {:error, :database_connection_error}

        {:error, reason} ->
          _ =
            Logger.error(
              "Error while initializing database: #{inspect(reason)}. ASTARTE WILL NOT WORK.",
              tag: "init_error"
            )

          {:error, reason}
      end
    end)
  end

  defp create_astarte_keyspace(conn) do
    # TODO: add support for creating the astarte keyspace with NetworkTopologyStrategy,
    # right now the replication factor is an integer so SimpleStrategy is always used
    astarte_keyspace_replication = Config.astarte_keyspace_replication_factor!()

    consistency = Consistency.domain_model(:write)

    with {:ok, replication_map_str} <- build_replication_map_str(astarte_keyspace_replication),
         query = """
         CREATE KEYSPACE #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}
         WITH replication = #{replication_map_str}
         AND durable_writes = true;
         """,
         :ok <- check_replication(conn, astarte_keyspace_replication),
         {:ok, %Xandra.SchemaChange{}} <-
           Xandra.execute(conn, query, %{}, consistency: consistency) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warning("Cannot create Astarte Keyspace: #{inspect(reason)}.",
            tag: "astarte_keyspace_creation_failed"
          )

        {:error, reason}
    end
  end

  defp create_realms_table(conn) do
    query = """
    CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms (
      realm_name varchar,
      device_registration_limit bigint,
      PRIMARY KEY (realm_name)
    );
    """

    consistency = Consistency.domain_model(:write)

    with {:ok, %Xandra.SchemaChange{}} <-
           Xandra.execute(conn, query, %{}, consistency: consistency) do
      :ok
    end
  end

  defp create_astarte_kv_store(conn) do
    query = """
    CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
    """

    consistency = Consistency.domain_model(:write)

    with {:ok, %Xandra.SchemaChange{}} <-
           Xandra.execute(conn, query, %{}, consistency: consistency) do
      :ok
    end
  end

  defp insert_astarte_schema_version(conn) do
    query = """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.kv_store
    (group, key, value)
    VALUES ('astarte', 'schema_version', bigintAsBlob(#{Migrator.latest_astarte_schema_version()}));
    """

    consistency = Consistency.domain_model(:write)

    with {:ok, %Xandra.Void{}} <- Xandra.execute(conn, query, %{}, consistency: consistency) do
      :ok
    end
  end

  def is_realm_existing(realm_name) do
    Xandra.Cluster.run(:xandra, &is_realm_existing(&1, realm_name))
  end

  def is_astarte_keyspace_existing do
    query = """
    SELECT keyspace_name
    FROM system_schema.keyspaces
    WHERE keyspace_name='#{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}'
    """

    consistency = Consistency.domain_model(:read)

    case Xandra.Cluster.execute(:xandra, query, %{}, consistency: consistency) do
      {:ok, %Xandra.Page{} = page} ->
        if Enum.count(page) > 0 do
          {:ok, true}
        else
          {:ok, false}
        end

      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  def list_realms do
    query = """
    SELECT realm_name
    FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms;
    """

    consistency = Consistency.domain_model(:read)

    case Xandra.Cluster.execute(:xandra, query, %{}, consistency: consistency) do
      {:ok, %Xandra.Page{} = page} ->
        {:ok, Enum.map(page, fn %{"realm_name" => realm_name} -> realm_name end)}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warning("Database error while listing realms: #{inspect(err)}.",
            tag: "database_error"
          )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error while listing realms: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  def get_realm(realm_name) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    Xandra.Cluster.run(:xandra, fn conn ->
      with {:ok, true} <- is_realm_existing(conn, realm_name),
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

            %{
              realm_name: realm_name,
              jwt_public_key_pem: public_key,
              replication_class: "SimpleStrategy",
              replication_factor: replication_factor,
              device_registration_limit: device_registration_limit,
              datastream_maximum_storage_retention: max_retention
            }

          %{"class" => "org.apache.cassandra.locator.NetworkTopologyStrategy"} ->
            datacenter_replication_factors =
              Enum.reduce(replication_map, %{}, fn
                {"class", _}, acc ->
                  acc

                {datacenter, replication_factor_string}, acc ->
                  {replication_factor, ""} = Integer.parse(replication_factor_string)
                  Map.put(acc, datacenter, replication_factor)
              end)

            %{
              realm_name: realm_name,
              jwt_public_key_pem: public_key,
              replication_class: "NetworkTopologyStrategy",
              datacenter_replication_factors: datacenter_replication_factors,
              device_registration_limit: device_registration_limit,
              datastream_maximum_storage_retention: max_retention
            }
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

  defp is_realm_existing(conn, realm_name) do
    query = """
    SELECT realm_name from #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
    WHERE realm_name=:realm_name;
    """

    consistency = Consistency.domain_model(:read)

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"realm_name" => realm_name}, consistency: consistency) do
      if Enum.count(page) > 0 do
        {:ok, true}
      else
        {:ok, false}
      end
    else
      {:error, reason} ->
        _ =
          Logger.warning("Cannot check if realm exists: #{inspect(reason)}.",
            tag: "is_realm_existing_error",
            realm: realm_name
          )

        {:error, reason}
    end
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

  # Replication factor of 1 is always ok
  defp check_replication(_conn, 1) do
    :ok
  end

  # If replication factor is an integer, we're using SimpleStrategy
  # Check that the replication factor is <= the number of nodes in the same datacenter
  defp check_replication(conn, replication_factor)
       when is_integer(replication_factor) and replication_factor > 1 do
    with {:ok, local_datacenter} <- get_local_datacenter(conn) do
      check_replication_for_datacenter(conn, local_datacenter, replication_factor, local: true)
    end
  end

  defp check_replication(conn, datacenter_replication_factors)
       when is_map(datacenter_replication_factors) do
    with {:ok, local_datacenter} <- get_local_datacenter(conn) do
      Enum.reduce_while(datacenter_replication_factors, :ok, fn
        {datacenter, replication_factor}, _acc ->
          opts =
            if datacenter == local_datacenter do
              [local: true]
            else
              []
            end

          case check_replication_for_datacenter(conn, datacenter, replication_factor, opts) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end)
    end
  end

  defp get_device_registration_limit(conn, realm_name) do
    query = """
    SELECT device_registration_limit
    FROM  #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
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

  defp get_local_datacenter(conn) do
    query = """
    SELECT data_center
    FROM system.local;
    """

    opts = [consistency: Consistency.domain_model(:read)]

    with {:ok, %Xandra.Page{} = page} <- Xandra.execute(conn, query, %{}, opts) do
      case Enum.fetch(page, 0) do
        {:ok, %{"data_center" => datacenter}} ->
          {:ok, datacenter}

        :error ->
          _ =
            Logger.error(
              "Empty dataset while getting local datacenter, something is really wrong.",
              tag: "get_local_datacenter_error"
            )

          {:error, :local_datacenter_not_found}
      end
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
    end
  end

  defp check_replication_for_datacenter(conn, datacenter, replication_factor, opts) do
    query = """
    SELECT COUNT(*)
    FROM system.peers
    WHERE data_center=:data_center
    ALLOW FILTERING;
    """

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"data_center" => datacenter}, opts) do
      case Enum.fetch(page, 0) do
        :error ->
          _ =
            Logger.warning("Cannot retrieve node count for datacenter #{datacenter}.",
              tag: "datacenter_not_found",
              datacenter: datacenter
            )

          {:error, :datacenter_not_found}

        {:ok, %{"count" => dc_node_count}} ->
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
            _ =
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
      end
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
    end
  end
end
