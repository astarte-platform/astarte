#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.Housekeeping.Queries do

  require Logger
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult

  @create_realm_queries [
    """
      CREATE KEYSPACE :realm_name
        WITH
          replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
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
        extended_id ascii,
        aliases map<ascii, varchar>,
        introspection map<ascii, int>,
        introspection_minor map<ascii, int>,
        protocol_revision int,
        metadata map<ascii, text>,
        inhibit_pairing boolean,
        cert_serial ascii,
        cert_aki ascii,
        first_pairing timestamp,
        last_connection timestamp,
        last_disconnection timestamp,
        connected boolean,
        pending_empty_cache boolean,
        total_received_msgs bigint,
        total_received_bytes bigint,
        last_pairing_ip inet,
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
        reliabilty int,
        retention int,
        expiry int,
        allow_unset boolean,

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
        quality int,
        flags int,
        source varchar,
        automaton_transitions blob,
        automaton_accepting_states blob,

        PRIMARY KEY (name, major_version)
      );
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
        (realm_name) VALUES (':realm_name');
    """
  ]

  @create_astarte_queries [
    """
      CREATE KEYSPACE astarte
        WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'}  AND
        durable_writes = true;
    """,
    """
      CREATE TABLE astarte.realms (
        realm_name varchar,
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
    SELECT * from astarte.realms WHERE realm_name=:realm_name;
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

  def create_realm(client, realm_name, public_key_pem) do
    if String.match?(realm_name, ~r/^[a-z][a-z0-9]*$/) do
      initialization_queries =
        for query <- @create_realm_queries do
          String.replace(query, ":realm_name", realm_name)
        end

      insert_pubkey_statement = String.replace(@insert_public_key_query, ":realm_name", realm_name)
      insert_pubkey_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(insert_pubkey_statement)
        |> DatabaseQuery.put(:pem, public_key_pem)

      exec_queries(client, initialization_queries ++ [insert_pubkey_query])
    else
      Logger.warn("HouseKeeping.Queries: " <> realm_name <> " is not an allowed realm name.")
      {:error, :realm_not_allowed}
    end

  end

  def create_astarte_keyspace(client) do
    exec_queries(client, @create_astarte_queries)
  end

  def realm_exists?(client, realm_name) do
    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@realm_exists_query)
      |> DatabaseQuery.put(:realm_name, realm_name)

    DatabaseQuery.call!(client, query)
    |> DatabaseResult.size() > 0
  end

  def astarte_keyspace_exists?(client) do
    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@astarte_keyspace_exists_query)

    # Try the query, if it returns an error we assume it doesn't exist
    # We can't query system tables since they differ between Cassandra 3.x and Scylla
    match?({:ok, _}, DatabaseQuery.call(client, query))
  end

  def realms_list(client) do
    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@realms_list_query)

    DatabaseQuery.call!(client, query)
    |> Enum.map(fn(row) -> row[:realm_name] end)
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
         [realm_name: ^realm_name] <- DatabaseResult.head(realm_result),
         {:ok, public_key_result} <- DatabaseQuery.call(client, public_key_query),
         ["system.blobasvarchar(value)": public_key] <- DatabaseResult.head(public_key_result) do
      %{realm_name: realm_name, jwt_public_key_pem: public_key}
    else
      _ ->
        {:error, :realm_not_found}
    end
  end

  defp exec_queries(client, _queries = [query | tail]) do
    case DatabaseQuery.call(client, query) do
      {:ok, _} -> exec_queries(client, tail)
      %{msg: message} -> {:error, message}
    end
  end

  defp exec_queries(_client, _queries = []) do
    :ok
  end

end
