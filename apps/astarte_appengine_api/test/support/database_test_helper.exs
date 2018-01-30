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

defmodule Astarte.RealmManagement.DatabaseTestHelper do
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Client, as: DatabaseClient
  alias Astarte.AppEngine.API.JWTTestHelper

  @create_autotestrealm """
    CREATE KEYSPACE autotestrealm
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """

  @create_kv_store """
    CREATE TABLE autotestrealm.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
  """

  @create_devices_table """
      CREATE TABLE autotestrealm.devices (
        device_id uuid,
        extended_id ascii,
        introspection map<ascii, int>,
        metadata map<ascii, text>,
        first_pairing timestamp,
        last_connection timestamp,
        last_disconnection timestamp,
        connected boolean,
        total_received_msgs bigint,
        total_received_bytes bigint,
        last_pairing_ip inet,
        last_seen_ip inet,

        PRIMARY KEY (device_id)
    );
  """

  @insert_pubkey_pem """
    INSERT INTO autotestrealm.kv_store (group, key, value)
    VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:pem));
  """

  @insert_device """
        INSERT INTO autotestrealm.devices (device_id, extended_id, connected, last_connection, last_disconnection, first_pairing, last_seen_ip, last_pairing_ip, total_received_msgs, total_received_bytes, introspection)
          VALUES (7f454c46-0201-0100-0000-000000000000, 'f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ', false, '2017-09-28 04:05+0020', '2017-09-30 04:05+0940', '2016-08-20 11:05+0121',
          '8.8.8.8', '4.4.4.4', 45000, 4500000, {'com.test.LCDMonitor' : 1, 'com.test.SimpleStreamTest' : 1, 'com.example.TestObject': 1});
  """

  @create_interfaces_table """
      CREATE TABLE autotestrealm.interfaces (
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
  """

  @create_endpoints_table """
      CREATE TABLE autotestrealm.endpoints (
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
  """

  @insert_endpoints [
  """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (bfc48596-1fad-b242-6521-435c00698fca, 9bfaca2e-cd94-1a67-0d5a-6e2b2071a777, False, '/time/from', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
  """,
  """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (bfc48596-1fad-b242-6521-435c00698fca, 465d0ef4-5ce3-20e4-9421-2ed7978a27da, False, '/time/to', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
  """,
  """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (bfc48596-1fad-b242-6521-435c00698fca, 83f40ec2-3cb3-320c-3fbe-790069524fe0, False, '/weekSchedule/%{day}/start', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
  """,
  """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (bfc48596-1fad-b242-6521-435c00698fca, a60682ff-036d-8d93-f3f8-f39730deba34, False, '/lcdCommand', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 7);
  """,
  """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (bfc48596-1fad-b242-6521-435c00698fca, b0443b22-613c-e593-76ea-3ece3f17abd9, False, '/weekSchedule/%{day}/stop', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
  """,
  """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (d2d90d55-a779-b988-9db4-15284b04f2e9, 1d0b2977-88e2-4285-c746-f5281a18bb94, False, '/%{itemIndex}/value', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 3);
  """,
  """
	INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (d2d90d55-a779-b988-9db4-15284b04f2e9, f9d39975-dd34-7da1-c073-e773e956864a, False, '/foo/%{param}/stringValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 7);
  """,
  """
	INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (d2d90d55-a779-b988-9db4-15284b04f2e9, 32e8adc5-ef41-8945-70a4-ee641a3e6992, False, '/foo/%{param}/blobValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 11);
  """,
  """
	INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (d2d90d55-a779-b988-9db4-15284b04f2e9, 6ee8a02a-01cf-c6ac-a81e-1b7fa8ae3166, False, '/foo/%{param}/longValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 5);
  """,
  """
	INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (d2d90d55-a779-b988-9db4-15284b04f2e9, f16391ce-d060-fd45-d655-384090817324, False, '/foo/%{param}/timestampValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 13);
  """,
  """
	INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (e7f6d126-ae91-9689-2dba-71a0be336507, ee440afe-1576-0c8e-4a8d-5ea603429f1d, False, '/string', 0, 1, 5, 'com.example.TestObject', 2, 2, 3, 7);
  """,
  """
	INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliabilty, retention, value_type) VALUES
      (e7f6d126-ae91-9689-2dba-71a0be336507, aae432cf-b8c3-34a1-33c1-082ed93c8b2a, False, '/value', 0, 1, 5, 'com.example.TestObject', 2, 2, 3, 1);
  """
  ]

  @create_individual_property_table """
    CREATE TABLE IF NOT EXISTS autotestrealm.individual_property (
      device_id uuid,
      interface_id uuid,
      endpoint_id uuid,
      path varchar,
      reception_timestamp timestamp,
      endpoint_tokens list<varchar>,

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

  @create_individual_datastream_table """
    CREATE TABLE IF NOT EXISTS autotestrealm.individual_datastream (
      device_id uuid,
      interface_id uuid,
      endpoint_id uuid,
      path varchar,
      value_timestamp timestamp,
      reception_timestamp timestamp,
      endpoint_tokens list<varchar>,

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

      PRIMARY KEY((device_id, interface_id), endpoint_id, path, value_timestamp, reception_timestamp)
    );
  """

  @create_test_object_table """
    CREATE TABLE autotestrealm.com_example_testobject_v1 (
      device_id uuid,
      reception_timestamp timestamp,
      string varchar,
      value double,
      PRIMARY KEY (device_id, reception_timestamp)
    );
  """

  @insert_values [
  """
    INSERT INTO autotestrealm.individual_property (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, bfc48596-1fad-b242-6521-435c00698fca, 9bfaca2e-cd94-1a67-0d5a-6e2b2071a777, '/time/from', 8);
  """,
  """
    INSERT INTO autotestrealm.individual_property (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, bfc48596-1fad-b242-6521-435c00698fca, 465d0ef4-5ce3-20e4-9421-2ed7978a27da, '/time/to', 20);
  """,
  """
    INSERT INTO autotestrealm.individual_property (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, bfc48596-1fad-b242-6521-435c00698fca, 83f40ec2-3cb3-320c-3fbe-790069524fe0, '/weekSchedule/2/start', 12);
  """,
  """
    INSERT INTO autotestrealm.individual_property (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, bfc48596-1fad-b242-6521-435c00698fca, 83f40ec2-3cb3-320c-3fbe-790069524fe0, '/weekSchedule/3/start', 15);
  """,
  """
    INSERT INTO autotestrealm.individual_property (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, bfc48596-1fad-b242-6521-435c00698fca, 83f40ec2-3cb3-320c-3fbe-790069524fe0, '/weekSchedule/4/start', 16);
  """,
  """
    INSERT INTO autotestrealm.individual_property (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, bfc48596-1fad-b242-6521-435c00698fca, b0443b22-613c-e593-76ea-3ece3f17abd9, '/weekSchedule/2/stop', 15);
  """,
  """
    INSERT INTO autotestrealm.individual_property (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, bfc48596-1fad-b242-6521-435c00698fca, b0443b22-613c-e593-76ea-3ece3f17abd9, '/weekSchedule/3/stop', 16);
  """,
  """
    INSERT INTO autotestrealm.individual_property (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, bfc48596-1fad-b242-6521-435c00698fca, b0443b22-613c-e593-76ea-3ece3f17abd9, '/weekSchedule/4/stop', 18);
  """,
  """
    INSERT INTO autotestrealm.individual_property (device_id, interface_id, endpoint_id, path, string_value) VALUES
     (7f454c46-0201-0100-0000-000000000000, bfc48596-1fad-b242-6521-435c00698fca, a60682ff-036d-8d93-f3f8-f39730deba34, '/lcdCommand', 'SWITCH_ON');
  """,
  """
    INSERT INTO autotestrealm.individual_datastream (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, integer_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, d2d90d55-a779-b988-9db4-15284b04f2e9, 1d0b2977-88e2-4285-c746-f5281a18bb94, '/0/value', '2017-09-28 04:05+0000', '2017-09-28 05:05+0000', 0);
  """,
  """
    INSERT INTO autotestrealm.individual_datastream (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, integer_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, d2d90d55-a779-b988-9db4-15284b04f2e9, 1d0b2977-88e2-4285-c746-f5281a18bb94, '/0/value', '2017-09-28 04:06+0000', '2017-09-28 05:06+0000', 1);
  """,
  """
    INSERT INTO autotestrealm.individual_datastream (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, integer_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, d2d90d55-a779-b988-9db4-15284b04f2e9, 1d0b2977-88e2-4285-c746-f5281a18bb94, '/0/value', '2017-09-28 04:07+0000', '2017-09-28 05:07+0000', 2);
  """,
  """
    INSERT INTO autotestrealm.individual_datastream (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, integer_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, d2d90d55-a779-b988-9db4-15284b04f2e9, 1d0b2977-88e2-4285-c746-f5281a18bb94, '/0/value', '2017-09-29 05:07+0000', '2017-09-29 06:07+0000', 3);
  """,
  """
    INSERT INTO autotestrealm.individual_datastream (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, integer_value) VALUES
      (7f454c46-0201-0100-0000-000000000000, d2d90d55-a779-b988-9db4-15284b04f2e9, 1d0b2977-88e2-4285-c746-f5281a18bb94, '/0/value', '2017-09-30 07:10+0000', '2017-09-30 08:10+0000', 4);
  """,
  """
    INSERT INTO autotestrealm.com_example_testobject_v1 (device_id, reception_timestamp, value, string) VALUES
      (7f454c46-0201-0100-0000-000000000000, '2017-09-30 07:10+0000', 1.1, 'aaa');
  """,
  """
    INSERT INTO autotestrealm.com_example_testobject_v1 (device_id, reception_timestamp, value, string) VALUES
      (7f454c46-0201-0100-0000-000000000000, '2017-09-30 07:12+0000', 2.2, 'bbb');
  """,
  """
    INSERT INTO autotestrealm.com_example_testobject_v1 (device_id, reception_timestamp, value, string) VALUES
      (7f454c46-0201-0100-0000-000000000000, '2017-09-30 07:13+0000', 3.3, 'ccc');
  """
  ]

  @insert_into_interface_0 """
  INSERT INTO autotestrealm.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, flags, interface_id, minor_version, quality, storage, storage_type, type) VALUES
    ('com.test.LCDMonitor', 1, :automaton_accepting_states, :automaton_transitions, 1, bfc48596-1fad-b242-6521-435c00698fca, 3, 1, 'individual_property', 1, 1)
  """

  @insert_into_interface_1 """
  INSERT INTO autotestrealm.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, flags, interface_id, minor_version, quality, storage, storage_type, type) VALUES
    ('com.test.SimpleStreamTest', 1, :automaton_accepting_states, :automaton_transitions, 1, d2d90d55-a779-b988-9db4-15284b04f2e9, 0, 1, 'individual_datastream', 2, 2)
  """

  @insert_into_interface_2 """
  INSERT INTO autotestrealm.interfaces (name, major_version, flags, interface_id, minor_version, quality, storage, storage_type, type) VALUES
    ('com.example.TestObject', 1, 2, e7f6d126-ae91-9689-2dba-71a0be336507, 5, 1, 'com_example_testobject_v1', 5, 2)
  """

  def create_test_keyspace do
    {:ok, client} = DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)))
    case DatabaseQuery.call(client, @create_autotestrealm) do
      {:ok, _} ->
        DatabaseQuery.call!(client, @create_devices_table)
        DatabaseQuery.call!(client, @insert_device)
        DatabaseQuery.call!(client, @create_kv_store)
        query =
          DatabaseQuery.new()
          |> DatabaseQuery.statement(@insert_pubkey_pem)
          |> DatabaseQuery.put(:pem, JWTTestHelper.public_key_pem())
        DatabaseQuery.call!(client, query)
        DatabaseQuery.call!(client, @create_endpoints_table)
        Enum.each(@insert_endpoints, fn(query) ->
          DatabaseQuery.call!(client, query)
        end)
        DatabaseQuery.call!(client, @create_individual_property_table)
        DatabaseQuery.call!(client, @create_individual_datastream_table)
        DatabaseQuery.call!(client, @create_test_object_table)
        Enum.each(@insert_values, fn(query) ->
          DatabaseQuery.call!(client, query)
        end)
        DatabaseQuery.call!(client, @create_interfaces_table)

        query =
          DatabaseQuery.new()
          |> DatabaseQuery.statement(@insert_into_interface_0)
          |> DatabaseQuery.put(:automaton_accepting_states,Base.decode64!("g3QAAAAFYQNtAAAAEIP0DsI8szIMP755AGlST+BhBG0AAAAQsEQ7ImE85ZN26j7OPxer2WEFbQAAABCmBoL/A22Nk/P485cw3ro0YQdtAAAAEJv6yi7NlBpnDVpuKyBxp3dhCG0AAAAQRl0O9FzjIOSUIS7Xl4on2g=="))
          |> DatabaseQuery.put(:automaton_transitions,Base.decode64!("g3QAAAAIaAJhAG0AAAAKbGNkQ29tbWFuZGEFaAJhAG0AAAAEdGltZWEGaAJhAG0AAAAMd2Vla1NjaGVkdWxlYQFoAmEBbQAAAABhAmgCYQJtAAAABXN0YXJ0YQNoAmECbQAAAARzdG9wYQRoAmEGbQAAAARmcm9tYQdoAmEGbQAAAAJ0b2EI"))
        DatabaseQuery.call!(client, query)

        query =
          DatabaseQuery.new()
          |> DatabaseQuery.statement(@insert_into_interface_1)
          |> DatabaseQuery.put(:automaton_accepting_states,Base.decode64!("g3QAAAAFYQJtAAAAEB0LKXeI4kKFx0b1KBoYu5RhBW0AAAAQ+dOZdd00faHAc+dz6VaGSmEGbQAAABAy6K3F70GJRXCk7mQaPmmSYQdtAAAAEG7ooCoBz8asqB4bf6iuMWZhCG0AAAAQ8WORztBg/UXWVThAkIFzJA=="))
          |> DatabaseQuery.put(:automaton_transitions,Base.decode64!("g3QAAAAIaAJhAG0AAAAAYQFoAmEAbQAAAANmb29hA2gCYQFtAAAABXZhbHVlYQJoAmEDbQAAAABhBGgCYQRtAAAACWJsb2JWYWx1ZWEGaAJhBG0AAAAJbG9uZ1ZhbHVlYQdoAmEEbQAAAAtzdHJpbmdWYWx1ZWEFaAJhBG0AAAAOdGltZXN0YW1wVmFsdWVhCA=="))
        DatabaseQuery.call!(client, query)

        query =
          DatabaseQuery.new()
          |> DatabaseQuery.statement(@insert_into_interface_2)
        DatabaseQuery.call!(client, query)

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
