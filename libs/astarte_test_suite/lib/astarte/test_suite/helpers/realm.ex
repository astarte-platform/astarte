#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.TestSuite.Helpers.Realm do
  @moduledoc false
  import Ecto.Query
  import ExUnit.Callbacks, only: [on_exit: 1]

  import Astarte.TestSuite.CaseContext, only: [ids: 2, put!: 5, put_fixture: 3, reduce: 4]

  alias Astarte.DataAccess.Repo

  alias Astarte.DataAccess.Realms.Realm, as: RealmData

  alias Astarte.Core.Generators.Realm, as: RealmGenerator

  def realm_names(%{realm_number: realm_number} = context),
    do:
      RealmGenerator.realm_name()
      |> Enum.take(realm_number * instances_count(context))
      |> unique_realm_names()

  def realms(%{realm_names: realm_names} = context) do
    realm_number =
      case Map.fetch(context, :realm_number) do
        {:ok, value} -> value
        :error -> names_count(realm_names)
      end

    {realm_context, _remaining_names} =
      reduce(context, :instances, {context, realm_names}, fn instance_id,
                                                             _instance,
                                                             nil,
                                                             {acc, names} ->
        {instance_realm_names, remaining_names} = Enum.split(names, realm_number)

        next_context =
          Enum.reduce(instance_realm_names, acc, fn realm_name, inner_acc ->
            put!(
              inner_acc,
              :realms,
              realm_name,
              realm_entry(instance_id, realm_name),
              instance_id
            )
          end)

        {next_context, remaining_names}
      end)

    realm_context
  end

  def data(context) do
    {realm_entries, keyspaces, statements} =
      reduce(context, :realms, {[], [], []}, fn _realm_id,
                                                realm,
                                                _instance_id,
                                                {realm_entries, keyspaces, statements} ->
        keyspace = realm_keyspace(realm)

        {
          realm_entries ++ [{keyspace, realm.id}],
          append_keyspace(keyspaces, keyspace),
          statements ++ realm_database_statements_for(realm)
        }
      end)

    Enum.each(statements, &Repo.query!/1)

    on_exit(fn ->
      Enum.each(realm_entries, &delete_realm/1)
    end)

    context
    |> put_fixture(:realm_data, %{
      realm_keyspaces: keyspaces,
      realm_database_statements: statements,
      realms_ready?: true
    })
  end

  defp instances_count(context), do: context |> ids(:instances) |> length()

  defp names_count(realm_names), do: length(realm_names)

  defp unique_realm_names(realm_names), do: Enum.map(realm_names, &unique_realm_name/1)

  defp unique_realm_name(realm_name) do
    realm_name <> Integer.to_string(System.unique_integer([:positive]))
  end

  defp realm_entry(instance_id, realm_name),
    do: %{id: realm_name, name: realm_name, instance_id: instance_id}

  defp realm_database_statements_for(%{instance_id: instance_id, id: realm_id}) do
    keyspace = instance_id

    [
      create_keyspace_statement(keyspace),
      insert_realm_statement(keyspace, realm_id)
    ] ++ realm_table_statements(keyspace)
  end

  defp realm_keyspace(%{instance_id: instance_id}), do: instance_id

  defp realm_table_statements(keyspace) do
    [
      create_devices_table_statement(keyspace),
      create_names_table_statement(keyspace),
      create_kv_store_statement(keyspace),
      create_endpoints_table_statement(keyspace),
      create_individual_properties_table_statement(keyspace),
      create_individual_datastreams_table_statement(keyspace),
      create_test_object_table_statement(keyspace),
      create_interfaces_table_statement(keyspace)
    ]
  end

  defp create_keyspace_statement(keyspace) do
    """
    CREATE KEYSPACE IF NOT EXISTS #{keyspace}
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
    """
    |> String.trim()
  end

  defp insert_realm_statement(instance_keyspace, realm_name) do
    """
    INSERT INTO #{instance_keyspace}.realms (realm_name, device_registration_limit)
    VALUES ('#{realm_name}', 0);
    """
    |> String.trim()
  end

  defp create_devices_table_statement(keyspace) do
    """
    CREATE TABLE IF NOT EXISTS #{keyspace}.devices (
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
    |> String.trim()
  end

  defp create_names_table_statement(keyspace) do
    """
    CREATE TABLE IF NOT EXISTS #{keyspace}.names (
      object_name varchar,
      object_type int,
      object_uuid uuid,
      PRIMARY KEY ((object_name), object_type)
    );
    """
    |> String.trim()
  end

  defp create_kv_store_statement(keyspace) do
    """
    CREATE TABLE IF NOT EXISTS #{keyspace}.kv_store (
      group varchar,
      key varchar,
      value blob,
      PRIMARY KEY ((group), key)
    );
    """
    |> String.trim()
  end

  defp create_endpoints_table_statement(keyspace) do
    """
    CREATE TABLE IF NOT EXISTS #{keyspace}.endpoints (
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
      database_retention_policy int,
      database_retention_ttl int,
      expiry int,
      allow_unset boolean,
      explicit_timestamp boolean,
      description varchar,
      doc varchar,
      PRIMARY KEY ((interface_id), endpoint_id)
    );
    """
    |> String.trim()
  end

  defp create_individual_properties_table_statement(keyspace) do
    """
    CREATE TABLE IF NOT EXISTS #{keyspace}.individual_properties (
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
    );
    """
    |> String.trim()
  end

  defp create_individual_datastreams_table_statement(keyspace) do
    """
    CREATE TABLE IF NOT EXISTS #{keyspace}.individual_datastreams (
      device_id uuid,
      interface_id uuid,
      endpoint_id uuid,
      path varchar,
      value_timestamp timestamp,
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
      PRIMARY KEY((device_id, interface_id, endpoint_id, path), value_timestamp, reception_timestamp, reception_timestamp_submillis)
    );
    """
    |> String.trim()
  end

  defp create_test_object_table_statement(keyspace) do
    """
    CREATE TABLE IF NOT EXISTS #{keyspace}.com_example_testobject_v1 (
      device_id uuid,
      path varchar,
      reception_timestamp timestamp,
      v_string varchar,
      v_value double,
      PRIMARY KEY ((device_id, path), reception_timestamp)
    );
    """
    |> String.trim()
  end

  defp create_interfaces_table_statement(keyspace) do
    """
    CREATE TABLE IF NOT EXISTS #{keyspace}.interfaces (
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
    |> String.trim()
  end

  defp append_keyspace(keyspaces, keyspace) do
    case keyspace in keyspaces do
      true -> keyspaces
      false -> keyspaces ++ [keyspace]
    end
  end

  defp delete_realm({keyspace, realm_name}) do
    RealmData
    |> where([realm], realm.realm_name == ^realm_name)
    |> Repo.safe_delete_all(prefix: keyspace)
  end
end
