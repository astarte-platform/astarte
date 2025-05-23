#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.DatabaseTestHelper do
  alias Astarte.DataAccess.Database
  alias CQEx.Query, as: DatabaseQuery
  alias Astarte.Core.Device
  alias Astarte.AppEngine.API.JWTTestHelper
  alias Astarte.Core.CQLUtils
  alias Astarte.AppEngine.API.Config

  @devices_list [
    {"f0VMRgIBAQAAAAAAAAAAAA", 4_500_000,
     %{
       {"com.example.TestObject", 1} => 9300,
       {"com.example.ServerOwnedTestObject", 1} => 100,
       {"com.example.PixelsConfiguration", 1} => 4230,
       {"com.test.LCDMonitor", 1} => 10,
       {"com.test.LCDMonitor", 0} => 42
     },
     %{
       {"com.example.TestObject", 1} => 2_000_000,
       {"com.example.ServerOwnedTestObject", 1} => 30_000,
       {"com.example.PixelsConfiguration", 1} => 2_010_000,
       {"com.test.LCDMonitor", 1} => 3000,
       {"com.test.LCDMonitor", 0} => 9000
     }, %{"display_name" => "device_a"}, %{"attribute_key" => "device_a_attribute"}},
    {"olFkumNuZ_J0f_d6-8XCDg", 10, nil, nil, nil, nil},
    {"4UQbIokuRufdtbVZt9AsLg", 22, %{{"com.test.LCDMonitor", 1} => 4},
     %{{"com.test.LCDMonitor", 1} => 16}, %{"display_name" => "device_b", "serial" => "1234"},
     %{"attribute_key" => "device_b_attribute"}},
    {"aWag-VlVKC--1S-vfzZ9uQ", 0, %{}, %{}, %{"display_name" => "device_c"},
     %{"attribute_key" => "device_c_attribute"}},
    {"DKxaeZ9LzUZLz7WPTTAEAA", 300, %{{"com.test.SimpleStreamTest", 1} => 9},
     %{{"com.test.SimpleStreamTest", 1} => 250}, %{"display_name" => "device_d"},
     %{"attribute_key" => "device_d_attribute"}},
    {"ehNpbPVtQ2CcdJdJK3QUlA", 300, %{{"com.test.SimpleStreamTest", 1} => 9},
     %{{"com.test.SimpleStreamTest", 1} => 250}, %{"display_name" => "device_e"},
     %{"attribute_key" => "device_e_attribute"}}
  ]

  @create_autotestrealm """
    CREATE KEYSPACE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """

  @create_kv_store """
    CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
  """

  @create_names_table """
    CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.names (
      object_name varchar,
      object_type int,
      object_uuid uuid,

      PRIMARY KEY ((object_name), object_type)
    );
  """

  @create_groups_table """
    CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.grouped_devices (
      group_name varchar,
      insertion_uuid timeuuid,
      device_id uuid,
      PRIMARY KEY ((group_name), insertion_uuid, device_id)
    );
  """

  @create_devices_table """
      CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.devices (
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
        exchanged_msgs_by_interface map<frozen<tuple<ascii, int>>, bigint>,
        exchanged_bytes_by_interface map<frozen<tuple<ascii, int>>, bigint>,
        last_credentials_request_ip inet,
        last_seen_ip inet,
        groups map<text, timeuuid>,
        attributes map<varchar, varchar>,

        PRIMARY KEY (device_id)
      );
  """

  @create_deletion_in_progress_table """
  CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.deletion_in_progress (
    device_id uuid PRIMARY KEY,
  );
  """

  @insert_pubkey_pem """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.kv_store (group, key, value)
    VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:pem));
  """

  @insert_device_statement """
  INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.devices
  (
     device_id, aliases, attributes, connected, last_connection, last_disconnection,
     first_registration, first_credentials_request, last_seen_ip, last_credentials_request_ip,
     total_received_msgs, total_received_bytes, inhibit_credentials_request,
     introspection, introspection_minor, exchanged_msgs_by_interface, exchanged_bytes_by_interface
  )
  VALUES
    (
      :device_id, :aliases, :attributes, false, '2017-09-28 04:05+0020', '2017-09-30 04:05+0940',
      '2016-08-15 11:05+0121', '2016-08-20 11:05+0121', '198.51.100.81', '198.51.100.89',
      45000, :total_received_bytes, false,
      {'com.test.LCDMonitor' : 1, 'com.test.SimpleStreamTest' : 1,
       'com.example.TestObject': 1, 'com.example.PixelsConfiguration': 1,
       'com.example.ServerOwnedTestObject': 1},
      {'com.test.LCDMonitor' : 3, 'com.test.SimpleStreamTest' : 0,
       'com.example.TestObject': 5, 'com.example.PixelsConfiguration': 0,
       'com.example.ServerOwnedTestObject': 0},
      :exchanged_msgs_by_interface, :exchanged_bytes_by_interface
    );
  """

  @insert_alias_statement """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.names (object_name, object_type, object_uuid) VALUES (:alias, 1, :device_id);
  """

  @create_interfaces_table """
      CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.interfaces (
        name ascii,
        major_version int,
        minor_version int,
        interface_id uuid,
        storage_type int,
        storage ascii,
        type int,
        ownership int,
        aggregation int,
        source varchar,
        automaton_transitions blob,
        automaton_accepting_states blob,

        PRIMARY KEY (name, major_version)
      );
  """

  @create_endpoints_table """
      CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (
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

        PRIMARY KEY ((interface_id), endpoint_id)
    );
  """

  @insert_endpoints [
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, e6f73631-effc-1d7e-ad52-d3f3a3bae50b, False, '/time/from', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 2b2c63dd-bbd9-5735-6d4a-8e56f504edda, False, '/time/to', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, False, '/weekSchedule/%{day}/start', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 4fe5034a-3d9b-99ec-7ec3-b23716303d33, False, '/lcdCommand', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 7);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, False, '/weekSchedule/%{day}/stop', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, False, '/%{itemIndex}/value', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 3);
    """,
    """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 3907d41d-5bca-329d-9e51-4cea2a54a99a, False, '/foo/%{param}/stringValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 7);
    """,
    """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 7aa44c11-2273-47d9-e624-4ae029dedeaa, False, '/foo/%{param}/blobValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 11);
    """,
    """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, eff957cf-03df-deed-9784-a8708e3d8cb9, False, '/foo/%{param}/longValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 5);
    """,
    """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 346c80e4-ca99-6274-81f6-7b1c1be59521, False, '/foo/%{param}/timestampValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 13);
    """,
    """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (db576345-80b1-5358-f305-d77ec39b3d84, 7c9f14e8-4f2f-977f-c126-d5e1bb9876e7, False, '/string', 0, 1, 5, 'com.example.TestObject', 2, 2, 3, 7);
    """,
    """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (db576345-80b1-5358-f305-d77ec39b3d84, 3b39fd3a-e261-26ff-e523-4c2dd150b864, False, '/value', 0, 1, 5, 'com.example.TestObject', 2, 2, 3, 1);
    """,
    """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (9651f167-a619-3ff5-1c4e-6771fb1929d4, 342c0830-f496-0db0-6776-2d1a7e534022, True, '/%{x}/%{y}/color', 0, 1, 0, 'com.example.PixelsConfiguration', 1, 1, 1, 7);
    """,
    """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (f0deb891-a02d-19db-ce8e-e8ed82c45587, 81da86f7-7a57-a0c1-ce84-363511058bf8, False, '/%{param}/string', 0, 1, 0, 'com.example.ServerOwnedTestObject', 2, 3, 1, 7);
    """,
    """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (f0deb891-a02d-19db-ce8e-e8ed82c45587, 3b937f4e-7e37-82f7-b19b-7244e8f530d5, False, '/%{param}/value', 0, 1, 0, 'com.example.ServerOwnedTestObject', 2, 3, 1, 1);
    """
  ]

  @create_individual_properties_table """
    CREATE TABLE IF NOT EXISTS #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (
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

  @create_individual_datastreams_table """
    CREATE TABLE IF NOT EXISTS #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_datastreams (
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

  @create_test_object_table """
    CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.com_example_testobject_v1 (
      device_id uuid,
      path varchar,
      reception_timestamp timestamp,
      v_string varchar,
      v_value double,
      PRIMARY KEY ((device_id, path), reception_timestamp)
    );
  """

  @insert_values [
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, e6f73631-effc-1d7e-ad52-d3f3a3bae50b, '/time/from', 8);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 2b2c63dd-bbd9-5735-6d4a-8e56f504edda, '/time/to', 20);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/2/start', 12);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/3/start', 15);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/4/start', 16);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/2/stop', 15);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/3/stop', 16);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/4/stop', 18);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (device_id, interface_id, endpoint_id, path, string_value) VALUES
       (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 4fe5034a-3d9b-99ec-7ec3-b23716303d33, '/lcdCommand', 'SWITCH_ON');
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:05+0000', '2017-09-28 05:05+0000', 0, 0);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:06+0000', '2017-09-28 05:06+0000', 0, 1);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:07+0000', '2017-09-28 05:07+0000', 0, 2);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-29 05:07+0000', '2017-09-29 06:07+0000', 0, 3);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-30 07:10+0000', '2017-09-30 08:10+0000', 0, 4);
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.com_example_testobject_v1 (device_id, path, reception_timestamp, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:10+0000', 1.1, 'aaa');
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.com_example_testobject_v1 (device_id, path, reception_timestamp, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:12+0000', 2.2, 'bbb');
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.com_example_testobject_v1 (device_id, path, reception_timestamp, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:13+0000', 3.3, 'ccc');
    """,
    """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.individual_properties (device_id, interface_id, endpoint_id, path, reception_timestamp) VALUES
        (7f454c46-0201-0100-0000-000000000000, db576345-80b1-5358-f305-d77ec39b3d84, 7d03ec11-a59f-47fa-c8f0-0bc9b022649f, '/', '2017-09-30 07:12+0000');
    """
  ]

  @insert_into_interface_0 """
  INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, aggregation, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
    ('com.test.LCDMonitor', 1, :automaton_accepting_states, :automaton_transitions, 1, 798b93a5-842e-bbad-2e4d-d20306838051, 3, 1, 'individual_properties', 1, 1)
  """

  @insert_into_interface_1 """
  INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, aggregation, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
    ('com.test.SimpleStreamTest', 1, :automaton_accepting_states, :automaton_transitions, 1, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 0, 1, 'individual_datastreams', 2, 2)
  """

  @insert_into_interface_2 """
  INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.interfaces (name, major_version, aggregation, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
    ('com.example.TestObject', 1, 2, db576345-80b1-5358-f305-d77ec39b3d84, 5, 1, 'com_example_testobject_v1', 5, 2)
  """

  @insert_into_interface_3 """
  INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, aggregation, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
    ('com.example.PixelsConfiguration', 1, :automaton_accepting_states, :automaton_transitions, 1, 9651f167-a619-3ff5-1c4e-6771fb1929d4, 0, 2, 'individual_properties', 1, 1)
  """

  @insert_into_interface_4 """
  INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, aggregation, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
    ('com.example.ServerOwnedTestObject', 1, :automaton_accepting_states, :automaton_transitions, 2, f0deb891-a02d-19db-ce8e-e8ed82c45587, 0, 2, 'com_example_testobject_v1', 5, 2)
  """

  def connect_to_test_keyspace() do
    Database.connect(realm: "autotestrealm")
  end

  def insert_empty_device(client, device_id) do
    insert_statement = "INSERT INTO devices (device_id) VALUES (:device_id)"

    insert_device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    DatabaseQuery.call!(client, insert_device_query)
  end

  def remove_device(client, device_id) do
    delete_statement = "DELETE FROM devices WHERE device_id=:device_id"

    delete_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    DatabaseQuery.call!(client, delete_query)
  end

  def insert_device_into_deletion_in_progress(client, device_id) do
    insert_statement = "INSERT INTO deletion_in_progress (device_id) VALUES (:device_id)"

    insert_device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    DatabaseQuery.call!(client, insert_device_query)
  end

  def create_test_keyspace do
    {:ok, client} = Database.connect()

    case DatabaseQuery.call(client, @create_autotestrealm) do
      {:ok, _} ->
        DatabaseQuery.call!(client, @create_devices_table)

        DatabaseQuery.call!(client, @create_deletion_in_progress_table)

        DatabaseQuery.call!(client, @create_names_table)

        DatabaseQuery.call!(client, @create_groups_table)

        DatabaseQuery.call!(client, @create_kv_store)

        DatabaseQuery.call!(client, @create_endpoints_table)

        DatabaseQuery.call!(client, @create_individual_properties_table)
        DatabaseQuery.call!(client, @create_individual_datastreams_table)
        DatabaseQuery.call!(client, @create_test_object_table)

        DatabaseQuery.call!(client, @create_interfaces_table)

        {:ok, client}

      %{msg: msg} ->
        {:error, msg}
    end
  end

  def create_public_key_only_keyspace do
    {:ok, client} = Database.connect(realm: "autotestrealm")

    DatabaseQuery.call!(client, @create_autotestrealm)

    DatabaseQuery.call!(client, @create_kv_store)

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_pubkey_pem)
      |> DatabaseQuery.put(:pem, JWTTestHelper.public_key_pem())

    DatabaseQuery.call!(client, query)
  end

  def seed_data do
    {:ok, client} = Database.connect(realm: "autotestrealm")

    Enum.each(
      [
        "interfaces",
        "endpoints",
        "individual_properties",
        "individual_datastreams",
        "kv_store",
        "devices",
        "grouped_devices",
        "deletion_in_progress"
      ],
      fn table ->
        DatabaseQuery.call!(
          client,
          "TRUNCATE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.#{table}"
        )
      end
    )

    insert_device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_device_statement)

    for {encoded_device_id, total_received_bytes, interface_msgs_map, interface_bytes_map,
         aliases, attributes} <- @devices_list do
      device_id = Base.url_decode64!(encoded_device_id, padding: false)

      insert_device_query =
        insert_device_query
        |> DatabaseQuery.put(:device_id, device_id)
        |> DatabaseQuery.put(:aliases, aliases)
        |> DatabaseQuery.put(:attributes, attributes)
        |> DatabaseQuery.put(:total_received_bytes, total_received_bytes)
        |> DatabaseQuery.put(:exchanged_msgs_by_interface, interface_msgs_map)
        |> DatabaseQuery.put(:exchanged_bytes_by_interface, interface_bytes_map)

      DatabaseQuery.call!(client, insert_device_query)

      for {_key, device_alias} <- aliases || %{} do
        insert_alias_query =
          DatabaseQuery.new()
          |> DatabaseQuery.statement(@insert_alias_statement)
          |> DatabaseQuery.put(:device_id, device_id)
          |> DatabaseQuery.put(:alias, device_alias)

        DatabaseQuery.call!(client, insert_alias_query)
      end
    end

    old_introspection_statement = """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.devices
    (device_id, old_introspection) VALUES (:device_id, :old_introspection)
    """

    old_introspection = %{{"com.test.LCDMonitor", 0} => 1}

    {:ok, device_id} = Astarte.Core.Device.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(old_introspection_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:old_introspection, old_introspection)

    DatabaseQuery.call!(client, query)

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_pubkey_pem)
      |> DatabaseQuery.put(:pem, JWTTestHelper.public_key_pem())

    DatabaseQuery.call!(client, query)

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_into_interface_0)
      |> DatabaseQuery.put(
        :automaton_accepting_states,
        Base.decode64!(
          "g3QAAAAFYQNtAAAAEIAeEDVf33Bpjm4/0nkmmathBG0AAAAQjrtis2DBS6JBcp3e3YCcn2EFbQAAABBP5QNKPZuZ7H7DsjcWMD0zYQdtAAAAEOb3NjHv/B1+rVLT86O65QthCG0AAAAQKyxj3bvZVzVtSo5W9QTt2g=="
        )
      )
      |> DatabaseQuery.put(
        :automaton_transitions,
        Base.decode64!(
          "g3QAAAAIaAJhAG0AAAAKbGNkQ29tbWFuZGEFaAJhAG0AAAAEdGltZWEGaAJhAG0AAAAMd2Vla1NjaGVkdWxlYQFoAmEBbQAAAABhAmgCYQJtAAAABXN0YXJ0YQNoAmECbQAAAARzdG9wYQRoAmEGbQAAAARmcm9tYQdoAmEGbQAAAAJ0b2EI"
        )
      )

    DatabaseQuery.call!(client, query)

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_into_interface_1)
      |> DatabaseQuery.put(
        :automaton_accepting_states,
        Base.decode64!(
          "g3QAAAAFYQJtAAAAEHUBDhsZnu783TXSVLDiCSRhBW0AAAAQOQfUHVvKMp2eUUzqKlSpmmEGbQAAABB6pEwRInNH2eYkSuAp3t6qYQdtAAAAEO/5V88D397tl4SocI49jLlhCG0AAAAQNGyA5MqZYnSB9nscG+WVIQ=="
        )
      )
      |> DatabaseQuery.put(
        :automaton_transitions,
        Base.decode64!(
          "g3QAAAAIaAJhAG0AAAAAYQFoAmEAbQAAAANmb29hA2gCYQFtAAAABXZhbHVlYQJoAmEDbQAAAABhBGgCYQRtAAAACWJsb2JWYWx1ZWEGaAJhBG0AAAAJbG9uZ1ZhbHVlYQdoAmEEbQAAAAtzdHJpbmdWYWx1ZWEFaAJhBG0AAAAOdGltZXN0YW1wVmFsdWVhCA=="
        )
      )

    DatabaseQuery.call!(client, query)

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_into_interface_2)

    DatabaseQuery.call!(client, query)

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_into_interface_3)
      |> DatabaseQuery.put(
        :automaton_accepting_states,
        Base.decode64!("g3QAAAABYQNtAAAAEOPZVKNVUNqw17mW3O0hiYc=")
      )
      |> DatabaseQuery.put(
        :automaton_transitions,
        Base.decode64!("g3QAAAADaAJhAG0AAAAAYQFoAmEBbQAAAABhAmgCYQJtAAAABWNvbG9yYQM=")
      )

    DatabaseQuery.call!(client, query)

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_into_interface_4)
      |> DatabaseQuery.put(
        :automaton_accepting_states,
        Base.decode64!("g3QAAAACYQJtAAAAEIHahvd6V6DBzoQ2NREFi/hhA20AAAAQO5N/Tn43gvexm3JE6PUw1Q==")
      )
      |> DatabaseQuery.put(
        :automaton_transitions,
        Base.decode64!("g3QAAAADaAJhAG0AAAAAYQFoAmEBbQAAAAZzdHJpbmdhAmgCYQFtAAAABXZhbHVlYQM=")
      )

    DatabaseQuery.call!(client, query)

    Enum.each(@insert_endpoints, fn query ->
      DatabaseQuery.call!(client, query)
    end)

    Enum.each(@insert_values, fn query ->
      DatabaseQuery.call!(client, query)
    end)

    for {encoded_device_id, _, _, _, _, _} <- @devices_list,
        encoded_device_id == "ehNpbPVtQ2CcdJdJK3QUlA" do
      {:ok, device_id} = Device.decode_device_id(encoded_device_id)
      insert_device_into_deletion_in_progress(client, device_id)
    end

    :ok
  end

  def fake_connect_device(encoded_device_id, connected) when is_boolean(connected) do
    {:ok, device_id} = Astarte.Core.Device.decode_device_id(encoded_device_id)

    Xandra.Cluster.run(:xandra, fn conn ->
      query = """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.devices
      (device_id, connected) VALUES (:device_id, :connected)
      """

      params = %{"device_id" => device_id, "connected" => connected}
      prepared = Xandra.prepare!(conn, query)
      %Xandra.Void{} = Xandra.execute!(conn, prepared, params)
    end)

    :ok
  end

  def create_datastream_receiving_device do
    {:ok, client} = Database.connect(realm: "autotestrealm")

    insert_datastream_receiving_device(client)
    insert_datastream_receiving_device_endpoints(client)
    insert_into_interface_datastream(client)
  end

  defp insert_datastream_receiving_device(client) do
    insert_datastream_receiving_device_query = """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.devices
    (
     device_id, aliases, attributes, connected, last_connection, last_disconnection,
     first_registration, first_credentials_request, last_seen_ip, last_credentials_request_ip,
     total_received_msgs, total_received_bytes, inhibit_credentials_request,
     introspection, introspection_minor, exchanged_msgs_by_interface, exchanged_bytes_by_interface
    )
    VALUES
    (
      :device_id, :aliases, :attributes, false, '2020-02-11 04:05+0020', '2020-02-10 04:05+0940',
      '2016-08-15 11:05+0121', '2016-08-20 11:05+0121', '198.51.100.81', '198.51.100.89',
      22000, 246, false,
      {'org.ServerOwnedIndividual': 0},
      {'org.ServerOwnedIndividual': 1},
      :exchanged_msgs_by_interface, :exchanged_bytes_by_interface
    );
    """

    {:ok, device_id} = Astarte.Core.Device.decode_device_id("fmloLzG5T5u0aOUfIkL8KA")

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_datastream_receiving_device_query)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:aliases, %{"display_name" => "receiving_device"})
      |> DatabaseQuery.put(:attributes, %{"device_attribute_key" => "device_attribute_value"})
      |> DatabaseQuery.put(:exchanged_msgs_by_interface, %{
        {"org.ServerOwnedIndividual", 0} => 16
      })
      |> DatabaseQuery.put(:exchanged_bytes_by_interface, %{
        {"org.ServerOwnedIndividual", 0} => 1024
      })

    DatabaseQuery.call!(client, query)
  end

  defp insert_datastream_receiving_device_endpoints(client) do
    insert_endpoint_query = """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints(interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
    (13ccc31d-f911-29df-cbe6-be22635293bd, 44c2421d-1abf-f3ec-14e1-986928d764aa, False, '/%{sensor_id}/samplingPeriod', 0, 0, 1, 'org.ServerOwnedIndividual', 2, 3, 1, 3);
    """

    DatabaseQuery.call!(client, insert_endpoint_query)
  end

  defp insert_into_interface_datastream(client) do
    insert_into_interface_datastream_query = """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, aggregation, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
    ('org.ServerOwnedIndividual', 0, :automaton_accepting_states, :automaton_transitions, 1, 13ccc31d-f911-29df-cbe6-be22635293bd, 1, 2, 'individual_datastreams', 2, 2);
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_into_interface_datastream_query)
      |> DatabaseQuery.put(
        :automaton_accepting_states,
        "83740000000161026d0000001044c2421d1abff3ec14e1986928d764aa"
        |> Base.decode16!(case: :lower)
      )
      |> DatabaseQuery.put(
        :automaton_transitions,
        "837400000002680261006d000000006101680261016d0000000e73616d706c696e67506572696f646102"
        |> Base.decode16!(case: :lower)
      )

    DatabaseQuery.call!(client, query)
  end

  def remove_datastream_receiving_device do
    {:ok, client} = Database.connect(realm: "autotestrealm")

    {:ok, device_id} = Astarte.Core.Device.decode_device_id("fmloLzG5T5u0aOUfIkL8KA")

    delete_query =
      "DELETE FROM #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.devices WHERE device_id=:device_id;"

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_query)
      |> DatabaseQuery.put(:device_id, device_id)

    DatabaseQuery.call!(client, query)

    query =
      "DELETE FROM #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints WHERE interface_id=13ccc31d-f911-29df-cbe6-be22635293bd;"

    DatabaseQuery.call!(client, query)

    query =
      "DELETE FROM #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.interfaces WHERE name='org.ServerOwnedIndividual';"

    DatabaseQuery.call!(client, query)
  end

  def create_object_receiving_device do
    {:ok, client} = Database.connect(realm: "autotestrealm")

    insert_object_receiving_device(client)
    create_server_owned_aggregated_object_table(client)
    insert_object_receiving_device_endpoints(client)
    insert_into_interface_obj_aggregated(client)
  end

  defp insert_object_receiving_device_endpoints(client) do
    insert_endpoint_queries = [
      """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints(interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
      (65c96ecb-f2d5-b440-4840-16cd84d2c2be, 76c99541-dd31-6369-bcdd-f2fdacc2d3ff, False, '/%{sensor_id}/enable', 0, 0, 1, 'org.astarte-platform.genericsensors.ServerOwnedAggregateObj', 2, 3, 1, 9);
      """,
      """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints(interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
      (65c96ecb-f2d5-b440-4840-16cd84d2c2be, 6ebd007e-dd74-8e32-f032-78d433b1b8e7, False, '/%{sensor_id}/samplingPeriod', 0, 0, 1, 'org.astarte-platform.genericsensors.ServerOwnedAggregateObj', 2, 3, 1, 3);
      """,
      """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints(interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
      (65c96ecb-f2d5-b440-4840-16cd84d2c2be, d42c4f4f-6faa-3f37-b38f-74602e7aec7d, False, '/%{sensor_id}/binaryblobarray', 0, 0, 1, 'org.astarte-platform.genericsensors.ServerOwnedAggregateObj', 2, 3, 1, 12);
      """
    ]

    Enum.each(insert_endpoint_queries, fn query ->
      DatabaseQuery.call!(client, query)
    end)
  end

  defp insert_into_interface_obj_aggregated(client) do
    insert_into_interface_obj_aggregated_query = """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, aggregation, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
    ('org.astarte-platform.genericsensors.ServerOwnedAggregateObj', 0, :automaton_accepting_states, :automaton_transitions, 2, 65c96ecb-f2d5-b440-4840-16cd84d2c2be, 1, 2, 'com_example_server_owned_aggregated_object_v1', 5, 2);
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_into_interface_obj_aggregated_query)
      |> DatabaseQuery.put(
        :automaton_accepting_states,
        "83740000000361026d0000001076c99541dd316369bcddf2fdacc2d3ff61036d000000106ebd007edd748e32f03278d433b1b8e761046d00000010d42c4f4f6faa3f37b38f74602e7aec7d"
        |> Base.decode16!(case: :lower)
      )
      |> DatabaseQuery.put(
        :automaton_transitions,
        "837400000004680261006d000000006101680261016d0000000f62696e617279626c6f6261727261796104680261016d00000006656e61626c656102680261016d0000000e73616d706c696e67506572696f646103"
        |> Base.decode16!(case: :lower)
      )

    DatabaseQuery.call!(client, query)
  end

  defp create_server_owned_aggregated_object_table(client) do
    create_server_owned_aggregated_object_table_query = """
    CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.com_example_server_owned_aggregated_object_v1 (
    device_id uuid,
    path varchar,
    reception_timestamp timestamp,
    reception_timestamp_submillis smallint,
    v_enable boolean,
    v_samplingPeriod int,
    v_binaryblobarray list<blob>,
    PRIMARY KEY ((device_id, path), reception_timestamp, reception_timestamp_submillis));
    """

    DatabaseQuery.call!(client, create_server_owned_aggregated_object_table_query)
  end

  defp insert_object_receiving_device(client) do
    insert_object_receiving_device_query = """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.devices
    (
     device_id, aliases, attributes, connected, last_connection, last_disconnection,
     first_registration, first_credentials_request, last_seen_ip, last_credentials_request_ip,
     total_received_msgs, total_received_bytes, inhibit_credentials_request,
     introspection, introspection_minor, exchanged_msgs_by_interface, exchanged_bytes_by_interface
    )
    VALUES
    (
      :device_id, :aliases, :attributes, false, '2020-02-11 04:05+0020', '2020-02-10 04:05+0940',
      '2016-08-15 11:05+0121', '2016-08-20 11:05+0121', '198.51.100.81', '198.51.100.89',
      45000, 1234, false,
      {'org.astarte-platform.genericsensors.ServerOwnedAggregateObj': 0},
      {'org.astarte-platform.genericsensors.ServerOwnedAggregateObj': 1},
      :exchanged_msgs_by_interface, :exchanged_bytes_by_interface
    );
    """

    {:ok, device_id} = Astarte.Core.Device.decode_device_id("fmloLzG5T5u0aOUfIkL8KA")

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_object_receiving_device_query)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:aliases, %{"display_name" => "receiving_device"})
      |> DatabaseQuery.put(:attributes, %{"obj_attribute_key" => "obj_attribute_value"})
      |> DatabaseQuery.put(:exchanged_msgs_by_interface, %{
        {"org.astarte-platform.genericsensors.ServerOwnedAggregateObj", 0} => 16
      })
      |> DatabaseQuery.put(:exchanged_bytes_by_interface, %{
        {"org.astarte-platform.genericsensors.ServerOwnedAggregateObj", 0} => 1024
      })

    DatabaseQuery.call!(client, query)
  end

  def remove_object_receiving_device do
    {:ok, client} = Database.connect(realm: "autotestrealm")

    {:ok, device_id} = Astarte.Core.Device.decode_device_id("fmloLzG5T5u0aOUfIkL8KA")

    delete_query =
      "DELETE FROM #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.devices WHERE device_id=:device_id;"

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_query)
      |> DatabaseQuery.put(:device_id, device_id)

    DatabaseQuery.call!(client, query)

    query =
      "DROP TABLE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.com_example_server_owned_aggregated_object_v1;"

    DatabaseQuery.call!(client, query)

    query =
      "DELETE FROM #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.endpoints WHERE interface_id=65c96ecb-f2d5-b440-4840-16cd84d2c2be;"

    DatabaseQuery.call!(client, query)

    query =
      "DELETE FROM #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.interfaces WHERE name='org.astarte-platform.genericsensors.ServerOwnedAggregateObj';"

    DatabaseQuery.call!(client, query)
  end

  def set_realm_ttl(ttl_s) do
    set_realm_ttl_statement = """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.kv_store (group, key, value)
      VALUES ('realm_config', 'datastream_maximum_storage_retention', intAsBlob(:ttl_s))
    """

    {:ok, client} = Database.connect(realm: "autotestrealm")

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(set_realm_ttl_statement)
      |> DatabaseQuery.put(:ttl_s, ttl_s)

    DatabaseQuery.call!(client, query)
  end

  def unset_realm_ttl do
    unset_realm_ttl_statement = """
      DELETE FROM #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())}.kv_store WHERE group='realm_config' AND key='datastream_maximum_storage_retention'
    """

    {:ok, client} = Database.connect(realm: "autotestrealm")

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(unset_realm_ttl_statement)

    DatabaseQuery.call!(client, query)
  end

  def devices_count do
    length(@devices_list)
  end

  def destroy_local_test_keyspace do
    {:ok, client} = Database.connect(realm: "autotestrealm")

    DatabaseQuery.call(
      client,
      "DROP KEYSPACE #{CQLUtils.realm_name_to_keyspace_name("autotestrealm", Config.astarte_instance_id!())};"
    )

    :ok
  end
end
