defmodule Housekeeping.Queries do

  alias CQEx.Query, as: DatabaseQuery

  def connect_to_local do
    {:ok, client} = CQEx.Client.new({"127.0.0.1", 9042})
    client
  end

  def create_realm(client, realm_name) do
    true = String.match?(realm_name, ~r/[a-z][a-z0-9]*/)

    create_realm_queries = [
      """
        CREATE KEYSPACE :realm_name
        WITH
          replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
          durable_writes = true;
      """,
      """
        CREATE TABLE :realm_name.devices (
          device_id ascii,
          introspection list<ascii>,
          last_connection timestamp,
          last_disconnection timestamp,
          connected boolean,
          protocol_revision int,
          PRIMARY KEY (device_id)
        );
      """,
      """
        CREATE TABLE :realm_name.endpoints (
          endpoint_id int,
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
          PRIMARY KEY (endpoint_id)
        );
      """,
      """
        CREATE TABLE :realm_name.interfaces (
          name ascii,
          major_version int,
          minor_version int,
          type int,
          quality int,
          flags int,
          source varchar,
          PRIMARY KEY (name, major_version)
        );
      """,
      """
      INSERT INTO astarte.realms
        (realm_name) VALUES (':realm_name');
      """
    ]

    for query_template <- create_realm_queries do
      query = String.replace(query_template, ":realm_name", realm_name)
      {:ok, _} = DatabaseQuery.call(client, query)
    end

    :ok
  end

  def create_astarte_keyspace(client) do
    create_astarte_queries = [
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

    for query <- create_astarte_queries do
      {:ok, _} = DatabaseQuery.call(client, query)
    end

    :ok
  end

end
