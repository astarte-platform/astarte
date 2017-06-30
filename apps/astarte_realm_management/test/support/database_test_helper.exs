defmodule Astarte.RealmManagement.DatabaseTestHelper do
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Client, as: DatabaseClient

  @create_autotestrealm """
    CREATE KEYSPACE autotestrealm
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """

  @create_interfaces_table """
      CREATE TABLE autotestrealm.interfaces (
        name ascii,
        major_version int,
        minor_version int,
        type int,
        quality int,
        flags int,
        source varchar,
        PRIMARY KEY (name, major_version)
      );
  """

  @create_endpoints_table """
      CREATE TABLE autotestrealm.endpoints (
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

        PRIMARY KEY (endpoint_id)
      );
  """

  def connect_to_test_database do
    {:ok, client} = DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)))
    case DatabaseQuery.call(client, @create_autotestrealm) do
      {:ok, _} ->
        DatabaseQuery.call!(client, @create_interfaces_table)
        DatabaseQuery.call!(client, @create_endpoints_table)
        {:ok, client}
      %{msg: msg} -> {:error, msg}
    end
  end

  def destroy_local_test_keyspace do
    {:ok, client} = DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)))
    DatabaseQuery.call(client, "DROP KEYSPACE autotestrealm;")
    :ok
  end

end
