defmodule Astarte.Pairing.DatabaseTestHelper do
  alias Astarte.Pairing.Config
  alias CQEx.Query
  alias CQEx.Client

  @create_autotestrealm """
  CREATE KEYSPACE autotestrealm
    WITH
    replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
    durable_writes = true;
  """

  @create_devices_table """
  CREATE TABLE autotestrealm.devices (
    device_id uuid,
    extended_id ascii,
    introspection set<ascii>,
    protocol_revision int,
    triggers set<ascii>,
    metadata map<ascii, text>,
    inhibit_pairing boolean,
    api_key ascii,
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
  """

  @drop_autotestrealm """
  DROP KEYSPACE autotestrealm;
  """

  @test_realm "autotestrealm"

  def test_realm(), do: @test_realm

  def seed_db do
    client =
      Config.cassandra_node()
      |> Client.new!()

    with {:ok, _} <- Query.call(client, @create_autotestrealm),
         {:ok, _} <- Query.call(client, @create_devices_table) do
      :ok
    else
      %{msg: msg} -> {:error, msg}
    end
  end

  def drop_db do
    client =
      Config.cassandra_node()
      |> Client.new!()

    Query.cast(client, @drop_autotestrealm)
  end
end
