#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Migrator

  @default_replication_factor 1

  def create_realm(realm_name, public_key_pem, nil = _replication_factor, opts) do
    create_realm(realm_name, public_key_pem, @default_replication_factor, opts)
  end

  def create_realm(realm_name, public_key_pem, replication, opts) do
    with :ok <- validate_realm_name(realm_name),
         :ok <- Xandra.Cluster.run(:xandra, &check_replication(&1, replication)),
         {:ok, replication_map_str} <- build_replication_map_str(replication) do
      if opts[:async] do
        {:ok, _pid} =
          Task.start(fn ->
            do_create_realm(realm_name, public_key_pem, replication_map_str)
          end)

        :ok
      else
        do_create_realm(realm_name, public_key_pem, replication_map_str)
      end
    end
  end

  def delete_realm(realm_name, opts \\ []) do
    if opts[:async] do
      {:ok, _pid} = Task.start(fn -> do_delete_realm(realm_name) end)

      :ok
    else
      do_delete_realm(realm_name)
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
        Logger.warn("Invalid realm name.",
          tag: "invalid_realm_name",
          realm: realm_name
        )

      {:error, :realm_not_allowed}
    end
  end

  defp do_delete_realm(realm_name) do
    Xandra.Cluster.run(:xandra, [timeout: 60_000], fn conn ->
      with :ok <- verify_realm_deletion_preconditions(conn, realm_name),
           :ok <- execute_realm_deletion(conn, realm_name) do
        :ok
      else
        {:error, reason} ->
          _ =
            Logger.warn("Cannot delete realm: #{inspect(reason)}.",
              tag: "realm_deletion_failed",
              realm: realm_name
            )

          {:error, reason}
      end
    end)
  end

  defp verify_realm_deletion_preconditions(conn, realm_name) do
    with :ok <- validate_realm_name(realm_name),
         :ok <- check_no_connected_devices(conn, realm_name) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warn("Realm deletion preconditions are not satisfied: #{inspect(reason)}.",
            tag: "realm_deletion_preconditions_rejected",
            realm: realm_name
          )

        {:error, reason}
    end
  end

  defp execute_realm_deletion(conn, realm_name) do
    with :ok <- delete_realm_keyspace(conn, realm_name),
         :ok <- remove_realm(conn, realm_name) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warn("Cannot delete realm: #{inspect(reason)}.",
            tag: "realm_deletion_failed",
            realm: realm_name
          )

        {:error, reason}
    end
  end

  defp do_create_realm(realm_name, public_key_pem, replication_map_str) do
    Xandra.Cluster.run(:xandra, [timeout: 60_000], fn conn ->
      with :ok <- validate_realm_name(realm_name),
           :ok <- create_realm_keyspace(conn, realm_name, replication_map_str),
           {:ok, realm_conn} <- build_realm_conn(conn, realm_name),
           :ok <- create_realm_kv_store(realm_conn),
           :ok <- create_names_table(realm_conn),
           :ok <- create_devices_table(realm_conn),
           :ok <- create_endpoints_table(realm_conn),
           :ok <- create_interfaces_table(realm_conn),
           :ok <- create_individual_properties_table(realm_conn),
           :ok <- create_simple_triggers_table(realm_conn),
           :ok <- create_grouped_devices_table(realm_conn),
           :ok <- create_deletion_in_progress_table(realm_conn),
           :ok <- insert_realm_public_key(realm_conn, public_key_pem),
           :ok <- insert_realm_astarte_schema_version(realm_conn),
           :ok <- insert_realm(realm_conn) do
        :ok
      else
        {:error, reason} ->
          _ =
            Logger.warn("Cannot create realm: #{inspect(reason)}.",
              tag: "realm_creation_failed",
              realm: realm_name
            )

          {:error, reason}
      end
    end)
  end

  defp build_realm_conn(conn, realm_name) do
    case validate_realm_name(realm_name) do
      :ok ->
        {:ok, {conn, realm_name}}

      {:error, reason} ->
        _ =
          Logger.warn("Cannot build realm conn: #{inspect(reason)}.",
            tag: "build_realm_conn_error",
            realm: realm_name
          )

        {:error, reason}
    end
  end

  defp check_no_connected_devices(conn, realm_name) do
    query = """
    SELECT * FROM #{realm_name}.devices WHERE connected = true LIMIT 1 ALLOW FILTERING;
    """

    with {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, query, %{}, consistency: :one) do
      if Enum.empty?(page) do
        :ok
      else
        _ =
          Logger.warn("Realm #{realm_name} still has connected devices.",
            tag: "connected_devices_present"
          )

        {:error, :connected_devices_present}
      end
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp delete_realm_keyspace(conn, realm_name) do
    query = """
    DROP KEYSPACE #{realm_name}
    """

    with {:ok, %Xandra.SchemaChange{}} <- CSystem.execute_schema_change(conn, query) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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

    case CSystem.execute_schema_change(conn, query) do
      {:ok, %Xandra.SchemaChange{}} ->
        :ok

      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{Exception.message(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{Exception.message(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp insert_realm_public_key({conn, realm}, public_key_pem) do
    query = """
    INSERT INTO #{realm}.kv_store (group, key, value)
    VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:public_key_pem));
    """

    params = %{"public_key_pem" => public_key_pem}

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, prepared, params, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp insert_realm_astarte_schema_version({conn, realm}) do
    query = """
    INSERT INTO #{realm}.kv_store
    (group, key, value)
    VALUES ('astarte', 'schema_version', bigintAsBlob(#{Migrator.latest_realm_schema_version()}));
    """

    with {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, query, %{}, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp remove_realm(conn, realm_name) do
    query = """
    DELETE FROM astarte.realms
    WHERE realm_name = :realm_name;
    """

    params = %{"realm_name" => realm_name}

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, prepared, params, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp insert_realm({conn, realm_name}) do
    query = """
    INSERT INTO astarte.realms (realm_name)
    VALUES (:realm_name);
    """

    params = %{"realm_name" => realm_name}

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, prepared, params, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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

    with {:ok, replication_map_str} <- build_replication_map_str(astarte_keyspace_replication),
         query = """
         CREATE KEYSPACE astarte
         WITH replication = #{replication_map_str}
         AND durable_writes = true;
         """,
         :ok <- check_replication(conn, astarte_keyspace_replication),
         {:ok, %Xandra.SchemaChange{}} <-
           Xandra.execute(conn, query, %{}, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}

      {:error, reason} ->
        _ =
          Logger.warn("Cannot create Astarte Keyspace: #{inspect(reason)}.",
            tag: "astarte_keyspace_creation_failed"
          )

        {:error, reason}
    end
  end

  defp create_realms_table(conn) do
    query = """
    CREATE TABLE astarte.realms (
      realm_name varchar,
      PRIMARY KEY (realm_name)
    );
    """

    with {:ok, %Xandra.SchemaChange{}} <-
           Xandra.execute(conn, query, %{}, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp create_astarte_kv_store(conn) do
    query = """
    CREATE TABLE astarte.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
    """

    with {:ok, %Xandra.SchemaChange{}} <-
           Xandra.execute(conn, query, %{}, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp insert_astarte_schema_version(conn) do
    query = """
    INSERT INTO astarte.kv_store
    (group, key, value)
    VALUES ('astarte', 'schema_version', bigintAsBlob(#{Migrator.latest_astarte_schema_version()}));
    """

    with {:ok, %Xandra.Void{}} <- Xandra.execute(conn, query, %{}, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  def is_realm_existing(realm_name) do
    Xandra.Cluster.run(:xandra, &is_realm_existing(&1, realm_name))
  end

  def is_astarte_keyspace_existing do
    query = """
    SELECT keyspace_name
    FROM system_schema.keyspaces
    WHERE keyspace_name='astarte'
    """

    case Xandra.Cluster.execute(:xandra, query) do
      {:ok, %Xandra.Page{} = page} ->
        if Enum.count(page) > 0 do
          {:ok, true}
        else
          {:ok, false}
        end

      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  def check_astarte_health(consistency) do
    query = """
    SELECT COUNT(*)
    FROM astarte.realms
    """

    with {:ok, %Xandra.Page{} = page} <-
           Xandra.Cluster.execute(:xandra, query, %{}, consistency: consistency),
         {:ok, _} <- Enum.fetch(page, 0) do
      :ok
    else
      :error ->
        _ =
          Logger.warn("Cannot retrieve count for astarte.realms table.",
            tag: "health_check_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warn("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  def list_realms do
    query = """
    SELECT realm_name
    FROM astarte.realms;
    """

    case Xandra.Cluster.execute(:xandra, query, %{}, consistency: :quorum) do
      {:ok, %Xandra.Page{} = page} ->
        {:ok, Enum.map(page, fn %{"realm_name" => realm_name} -> realm_name end)}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warn("Database error while listing realms: #{inspect(err)}.",
            tag: "database_error"
          )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error while listing realms: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  def get_realm(realm_name) do
    Xandra.Cluster.run(:xandra, fn conn ->
      with {:ok, true} <- is_realm_existing(conn, realm_name),
           {:ok, public_key} <- get_public_key(conn, realm_name),
           {:ok, replication_map} <- get_realm_replication(conn, realm_name) do
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
              replication_factor: replication_factor
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
              datacenter_replication_factors: datacenter_replication_factors
            }
        end
      else
        # Returned by is_realm_existing
        {:ok, false} ->
          {:error, :realm_not_found}

        {:error, reason} ->
          _ =
            Logger.warn("Error while getting realm: #{inspect(reason)}.",
              tag: "get_realm_error",
              realm: realm_name
            )

          {:error, reason}
      end
    end)
  end

  defp is_realm_existing(conn, realm_name) do
    query = """
    SELECT realm_name from astarte.realms
    WHERE realm_name=:realm_name;
    """

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"realm_name" => realm_name}, consistency: :quorum) do
      if Enum.count(page) > 0 do
        {:ok, true}
      else
        {:ok, false}
      end
    else
      {:error, reason} ->
        _ =
          Logger.warn("Cannot check if realm exists: #{inspect(reason)}.",
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

    with :ok <- validate_realm_name(realm_name),
         query = String.replace(statement, ":realm_name", realm_name),
         {:ok, %Xandra.Page{} = page} <- Xandra.execute(conn, query, %{}, consistency: :quorum) do
      case Enum.fetch(page, 0) do
        {:ok, %{"system.blobasvarchar(value)" => public_key}} ->
          {:ok, public_key}

        :error ->
          {:error, :public_key_not_found}
      end
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}

      {:error, reason} ->
        _ =
          Logger.warn("Cannot get public key: #{inspect(reason)}.",
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

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, page} <- Xandra.execute(conn, prepared, %{"realm_name" => realm_name}) do
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
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
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

  defp get_local_datacenter(conn) do
    query = """
    SELECT data_center
    FROM system.local;
    """

    with {:ok, %Xandra.Page{} = page} <- Xandra.execute(conn, query) do
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
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
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
           Xandra.execute(conn, prepared, %{"data_center" => datacenter}) do
      case Enum.fetch(page, 0) do
        :error ->
          _ =
            Logger.warn("Cannot retrieve node count for datacenter #{datacenter}.",
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
              Logger.warn(
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
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end
end
