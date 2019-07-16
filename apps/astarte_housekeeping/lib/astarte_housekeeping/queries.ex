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

defmodule Astarte.Housekeeping.Queries do
  require Logger
  alias Astarte.Housekeeping.Config
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult

  @create_realm_queries [
    """
      CREATE KEYSPACE :realm_name
        WITH
          replication = {'class': 'SimpleStrategy', 'replication_factor': :replication_factor} AND
          durable_writes = true;
    """,
    """
      CREATE TABLE :realm_name.kv_store (
        group varchar,
        key varchar,
        value blob,

        PRIMARY KEY ((group), key)
      );
    """,
    """
      CREATE TABLE :realm_name.names (
        object_name varchar,
        object_type int,
        object_uuid uuid,

        PRIMARY KEY ((object_name), object_type)
      );
    """,
    """
      CREATE TABLE :realm_name.devices (
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
        last_credentials_request_ip inet,
        last_seen_ip inet,

        PRIMARY KEY (device_id)
      );
    """,
    """
      CREATE TABLE :realm_name.endpoints (
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
        allow_unset boolean,
        explicit_timestamp boolean,
        description varchar,
        doc varchar,

        PRIMARY KEY ((interface_id), endpoint_id)
      );
    """,
    """
      CREATE TABLE :realm_name.interfaces (
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
    """,
    """
    CREATE TABLE :realm_name.individual_properties (
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
    """,
    """
      CREATE TABLE :realm_name.simple_triggers (
        object_id uuid,
        object_type int,
        parent_trigger_id uuid,
        simple_trigger_id uuid,
        trigger_data blob,
        trigger_target blob,

        PRIMARY KEY ((object_id, object_type), parent_trigger_id, simple_trigger_id)
      );
    """,
    """
      INSERT INTO astarte.realms
        (realm_name, replication_factor) VALUES (':realm_name', :replication_factor);
    """
  ]

  @create_astarte_queries [
    """
      CREATE KEYSPACE astarte
        WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': :replication_factor}  AND
        durable_writes = true;
    """,
    """
      CREATE TABLE astarte.realms (
        realm_name varchar,
        replication_factor int,
        PRIMARY KEY (realm_name)
      );
    """,
    """
      CREATE TABLE astarte.astarte_schema (
        config_key varchar,
        config_value varchar,
        PRIMARY KEY (config_key)
      );
    """,
    """
      INSERT INTO astarte.astarte_schema
        (config_key, config_value) VALUES ('schema_version', '0');
    """
  ]

  @realm_exists_query """
    SELECT realm_name FROM astarte.realms WHERE realm_name=:realm_name;
  """

  @astarte_keyspace_exists_query """
    SELECT config_value FROM astarte.astarte_schema WHERE config_key='schema_version'
  """

  @realms_list_query """
    SELECT realm_name FROM astarte.realms;
  """

  @get_realm_query """
    SELECT realm_name, replication_factor from astarte.realms WHERE realm_name=:realm_name;
  """

  # TODO: this should be done with a generic insert_kv_store_query
  # but we need to handle the different xAsBlob() functions
  @insert_public_key_query """
    INSERT INTO :realm_name.kv_store (group, key, value)
    VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:pem));
  """

  @get_public_key_query """
    SELECT blobAsVarchar(value)
    FROM :realm_name.kv_store
    WHERE group='auth' AND key='jwt_public_key_pem';
  """

  @default_replication_factor 1

  def create_realm(client, realm_name, public_key_pem, nil = _replication_factor) do
    create_realm(client, realm_name, public_key_pem, @default_replication_factor)
  end

  def create_realm(client, realm_name, public_key_pem, replication_factor)
      when is_integer(replication_factor) and replication_factor > 0 do
    if String.match?(realm_name, ~r/^[a-z][a-z0-9]*$/) do
      replication_factor_str = Integer.to_string(replication_factor)

      initialization_queries =
        for query <- @create_realm_queries do
          String.replace(query, ":realm_name", realm_name)
          |> String.replace(":replication_factor", replication_factor_str)
        end

      insert_pubkey_statement =
        String.replace(@insert_public_key_query, ":realm_name", realm_name)

      insert_pubkey_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(insert_pubkey_statement)
        |> DatabaseQuery.put(:pem, public_key_pem)

      with :ok <- exec_queries(client, initialization_queries ++ [insert_pubkey_query]) do
        Logger.info("create_realm: #{realm_name} creation succeed.")
        :ok
      else
        {:error, :database_error} ->
          Logger.warn("create_realm: #{realm_name} creation failed.")
          {:error, :database_error}
      end
    else
      Logger.warn("HouseKeeping.Queries: " <> realm_name <> " is not an allowed realm name.")
      {:error, :realm_not_allowed}
    end
  end

  def create_astarte_keyspace(client) do
    replication_factor_str =
      Config.astarte_keyspace_replication_factor()
      |> Integer.to_string()

    queries =
      for query <- @create_astarte_queries do
        String.replace(query, ":replication_factor", replication_factor_str)
      end

    with :ok <- exec_queries(client, queries) do
      Logger.info("Astarte keyspace creation has succeed.")
      :ok
    else
      {:error, :database_error} ->
        Logger.error("Astarte keyspace creation failed. ASTARTE WILL NOT WORK.")
        {:error, :database_error}
    end
  end

  def realm_exists?(client, realm_name) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@realm_exists_query)
      |> DatabaseQuery.put(:realm_name, realm_name)

    DatabaseQuery.call!(client, query)
    |> DatabaseResult.size() > 0
  end

  def astarte_keyspace_exists?(client) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@astarte_keyspace_exists_query)

    # Try the query, if it returns an error we assume it doesn't exist
    # We can't query system tables since they differ between Cassandra 3.x and Scylla
    match?({:ok, _}, DatabaseQuery.call(client, query))
  end

  def check_astarte_health(client, consistency) do
    realms_count_statement = """
    SELECT COUNT(*)
    FROM astarte.realms
    """

    realms_count_statement =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(realms_count_statement)
      |> DatabaseQuery.consistency(consistency)

    with {:ok, result} <- DatabaseQuery.call(client, realms_count_statement),
         [count: _count] <- DatabaseResult.head(result) do
      :ok
    else
      %{acc: _, msg: err_msg} ->
        Logger.warn("Health is not good: #{err_msg}")

        {:error, :health_check_bad}

      {:error, err} ->
        Logger.warn("Health is not good, reason: #{inspect(err)}.")

        {:error, :health_check_bad}
    end
  end

  def realms_list(client) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@realms_list_query)

    DatabaseQuery.call!(client, query)
    |> Enum.map(fn row -> row[:realm_name] end)
  end

  def get_realm(client, realm_name) do
    realm_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@get_realm_query)
      |> DatabaseQuery.put(:realm_name, realm_name)

    public_key_statement = String.replace(@get_public_key_query, ":realm_name", realm_name)

    public_key_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(public_key_statement)

    with {:ok, realm_result} <- DatabaseQuery.call(client, realm_query),
         [realm_name: ^realm_name, replication_factor: replication_factor] <-
           DatabaseResult.head(realm_result),
         {:ok, public_key_result} <- DatabaseQuery.call(client, public_key_query),
         ["system.blobasvarchar(value)": public_key] <- DatabaseResult.head(public_key_result) do
      %{
        realm_name: realm_name,
        jwt_public_key_pem: public_key,
        replication_factor: replication_factor
      }
    else
      _ ->
        {:error, :realm_not_found}
    end
  end

  defp exec_queries(client, queries) do
    Enum.reduce_while(queries, :ok, fn query, _acc ->
      with {:ok, _result} <- DatabaseQuery.call(client, query) do
        {:cont, :ok}
      else
        %{acc: _, msg: error_message} ->
          Logger.warn("exec_queries: database error: #{error_message}")
          {:halt, {:error, :database_error}}

        {:error, reason} ->
          Logger.warn("exec_queries: failed with reason #{inspect(reason)}")
          {:halt, {:error, :database_error}}
      end
    end)
  end
end
