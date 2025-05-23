#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Helpers.Database do
  import Ecto.Query

  alias Astarte.DataAccess.Interface
  alias Astarte.Core.Device
  alias Astarte.Helpers.JWT, as: JWTTestHelper
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Devices.Device, as: DeviceSchema
  alias Astarte.DataAccess.KvStore
  alias Astarte.AppEngine.API.Repo
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.Endpoint, as: EndpointSchema
  alias Astarte.DataAccess.Realms.Name

  require Logger

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

  @test_realm "autotestrealm"

  @create_autotestrealm """
    CREATE KEYSPACE #{Realm.keyspace_name(@test_realm)}
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """

  @create_kv_store """
    CREATE TABLE #{Realm.keyspace_name(@test_realm)}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
  """

  @create_names_table """
    CREATE TABLE #{Realm.keyspace_name(@test_realm)}.names (
      object_name varchar,
      object_type int,
      object_uuid uuid,

      PRIMARY KEY ((object_name), object_type)
    );
  """

  @create_groups_table """
    CREATE TABLE #{Realm.keyspace_name(@test_realm)}.grouped_devices (
      group_name varchar,
      insertion_uuid timeuuid,
      device_id uuid,

      PRIMARY KEY ((group_name), insertion_uuid, device_id)
    );
  """

  @create_devices_table """
      CREATE TABLE #{Realm.keyspace_name(@test_realm)}.devices (
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

  @create_deletion_in_progress_table """
  CREATE TABLE #{Realm.keyspace_name(@test_realm)}.deletion_in_progress (
    device_id uuid,
    vmq_ack boolean,
    dup_start_ack boolean,
    dup_end_ack boolean,

    PRIMARY KEY (device_id)
  );
  """

  @create_interfaces_table """
      CREATE TABLE #{Realm.keyspace_name(@test_realm)}.interfaces (
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

  @create_endpoints_table """
      CREATE TABLE #{Realm.keyspace_name(@test_realm)}.endpoints (
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

  @insert_endpoints [
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, e6f73631-effc-1d7e-ad52-d3f3a3bae50b, False, '/time/from', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 2b2c63dd-bbd9-5735-6d4a-8e56f504edda, False, '/time/to', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, False, '/weekSchedule/%{day}/start', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 4fe5034a-3d9b-99ec-7ec3-b23716303d33, False, '/lcdCommand', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 7);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, False, '/weekSchedule/%{day}/stop', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, False, '/%{itemIndex}/value', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 3);
    """,
    """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 3907d41d-5bca-329d-9e51-4cea2a54a99a, False, '/foo/%{param}/stringValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 7);
    """,
    """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 7aa44c11-2273-47d9-e624-4ae029dedeaa, False, '/foo/%{param}/blobValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 11);
    """,
    """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, eff957cf-03df-deed-9784-a8708e3d8cb9, False, '/foo/%{param}/longValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 5);
    """,
    """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 346c80e4-ca99-6274-81f6-7b1c1be59521, False, '/foo/%{param}/timestampValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 13);
    """,
    """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (db576345-80b1-5358-f305-d77ec39b3d84, 7c9f14e8-4f2f-977f-c126-d5e1bb9876e7, False, '/string', 0, 1, 5, 'com.example.TestObject', 2, 2, 3, 7);
    """,
    """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (db576345-80b1-5358-f305-d77ec39b3d84, 3b39fd3a-e261-26ff-e523-4c2dd150b864, False, '/value', 0, 1, 5, 'com.example.TestObject', 2, 2, 3, 1);
    """,
    """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (9651f167-a619-3ff5-1c4e-6771fb1929d4, 342c0830-f496-0db0-6776-2d1a7e534022, True, '/%{x}/%{y}/color', 0, 1, 0, 'com.example.PixelsConfiguration', 1, 1, 1, 7);
    """,
    """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (f0deb891-a02d-19db-ce8e-e8ed82c45587, 81da86f7-7a57-a0c1-ce84-363511058bf8, False, '/%{param}/string', 0, 1, 0, 'com.example.ServerOwnedTestObject', 2, 3, 1, 7);
    """,
    """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (f0deb891-a02d-19db-ce8e-e8ed82c45587, 3b937f4e-7e37-82f7-b19b-7244e8f530d5, False, '/%{param}/value', 0, 1, 0, 'com.example.ServerOwnedTestObject', 2, 3, 1, 1);
    """
  ]

  @create_individual_properties_table """
    CREATE TABLE IF NOT EXISTS #{Realm.keyspace_name(@test_realm)}.individual_properties (
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
    CREATE TABLE IF NOT EXISTS #{Realm.keyspace_name(@test_realm)}.individual_datastreams (
      device_id uuid,
      interface_id uuid,
      endpoint_id uuid,
      path text,
      value_timestamp timestamp,
      reception_timestamp timestamp,
      reception_timestamp_submillis smallint,
      binaryblob_value blob,
      binaryblobarray_value list<blob>,
      boolean_value boolean,
      booleanarray_value list<boolean>,
      datetime_value timestamp,
      datetimearray_value list<timestamp>,
      double_value double,
      doublearray_value list<double>,
      integer_value int,
      integerarray_value list<int>,
      longinteger_value bigint,
      longintegerarray_value list<bigint>,
      string_value text,
      stringarray_value list<text>,

      PRIMARY KEY((device_id, interface_id, endpoint_id, path), value_timestamp, reception_timestamp, reception_timestamp_submillis)
    );
  """

  @create_test_object_table """
    CREATE TABLE #{Realm.keyspace_name(@test_realm)}.com_example_testobject_v1 (
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
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, e6f73631-effc-1d7e-ad52-d3f3a3bae50b, '/time/from', 8);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 2b2c63dd-bbd9-5735-6d4a-8e56f504edda, '/time/to', 20);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/2/start', 12);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/3/start', 15);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/4/start', 16);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/2/stop', 15);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/3/stop', 16);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/4/stop', 18);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties (device_id, interface_id, endpoint_id, path, string_value) VALUES
       (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 4fe5034a-3d9b-99ec-7ec3-b23716303d33, '/lcdCommand', 'SWITCH_ON');
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:05+0000', '2017-09-28 05:05+0000', 0, 0);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:06+0000', '2017-09-28 05:06+0000', 0, 1);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:07+0000', '2017-09-28 05:07+0000', 0, 2);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-29 05:07+0000', '2017-09-29 06:07+0000', 0, 3);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-30 07:10+0000', '2017-09-30 08:10+0000', 0, 4);
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.com_example_testobject_v1 (device_id, path, reception_timestamp, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:10+0000', 1.1, 'aaa');
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.com_example_testobject_v1 (device_id, path, reception_timestamp, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:12+0000', 2.2, 'bbb');
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.com_example_testobject_v1 (device_id, path, reception_timestamp, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:13+0000', 3.3, 'ccc');
    """,
    """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties (device_id, interface_id, endpoint_id, path, reception_timestamp) VALUES
        (7f454c46-0201-0100-0000-000000000000, db576345-80b1-5358-f305-d77ec39b3d84, 7d03ec11-a59f-47fa-c8f0-0bc9b022649f, '/', '2017-09-30 07:12+0000');
    """
  ]

  def insert_empty_device(device_id) do
    keyspace_name = Realm.keyspace_name(@test_realm)

    %DeviceSchema{device_id: device_id}
    |> Ecto.Changeset.change()
    |> Repo.insert!(prefix: keyspace_name)
  end

  def remove_device(device_id) do
    keyspace_name = Realm.keyspace_name(@test_realm)

    Repo.delete_all(
      from d in DeviceSchema,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id
    )
  end

  def insert_device_into_deletion_in_progress(device_id) do
    keyspace_name = Realm.keyspace_name(@test_realm)

    %DeletionInProgress{device_id: device_id}
    |> Ecto.Changeset.change()
    |> Repo.insert!(prefix: keyspace_name)
  end

  def create_test_keyspace do
    destroy_local_test_keyspace()

    case Repo.query(@create_autotestrealm) do
      {:ok, _} ->
        Repo.query!(@create_devices_table)

        Repo.query!(@create_deletion_in_progress_table)

        Repo.query!(@create_names_table)

        Repo.query!(@create_groups_table)

        Repo.query!(@create_kv_store)

        Repo.query!(@create_endpoints_table)

        Repo.query!(@create_individual_properties_table)

        Repo.query!(@create_individual_datastreams_table)

        Repo.query!(@create_test_object_table)

        Repo.query!(@create_interfaces_table)

        :ok

      %{msg: msg} ->
        {:error, msg}
    end
  end

  def create_public_key_only_keyspace do
    keyspace_name = Realm.keyspace_name(@test_realm)

    Repo.query!(@create_autotestrealm)
    Repo.query!(@create_kv_store)

    kv_store_map = %{
      group: "auth",
      key: "jwt_public_key_pem",
      value: JWTTestHelper.public_key_pem()
    }

    KvStore.insert(kv_store_map, prefix: keyspace_name)
  end

  def seed_data do
    keyspace_name = Realm.keyspace_name(@test_realm)

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
        Repo.query!("TRUNCATE #{Realm.keyspace_name(@test_realm)}.#{table}")
      end
    )

    for {encoded_device_id, total_received_bytes, interface_msgs_map, interface_bytes_map,
         aliases, attributes} <- @devices_list do
      device_id = Base.url_decode64!(encoded_device_id, padding: false)

      %DeviceSchema{}
      |> Ecto.Changeset.change(%{
        device_id: device_id,
        aliases: aliases,
        attributes: attributes,
        connected: false,
        last_connection: ~U[2017-09-28 03:45:00Z],
        last_disconnection: ~U[2017-09-29 18:25:00Z],
        first_registration: ~U[2016-08-15 09:44:00Z],
        first_credentials_request: ~U[2016-08-20 09:44:00Z],
        last_seen_ip: {198, 51, 100, 81},
        last_credentials_request_ip: {198, 51, 100, 89},
        total_received_msgs: 45000,
        total_received_bytes: total_received_bytes,
        inhibit_credentials_request: false,
        introspection: %{
          "com.test.LCDMonitor" => 1,
          "com.test.SimpleStreamTest" => 1,
          "com.example.TestObject" => 1,
          "com.example.PixelsConfiguration" => 1,
          "com.example.ServerOwnedTestObject" => 1
        },
        introspection_minor: %{
          "com.test.LCDMonitor" => 3,
          "com.test.SimpleStreamTest" => 0,
          "com.example.TestObject" => 5,
          "com.example.PixelsConfiguration" => 0,
          "com.example.ServerOwnedTestObject" => 0
        },
        exchanged_msgs_by_interface: interface_msgs_map,
        exchanged_bytes_by_interface: interface_bytes_map
      })
      |> Repo.insert!(prefix: keyspace_name)

      for {_key, device_alias} <- aliases || %{} do
        %Name{}
        |> Ecto.Changeset.change(%{
          object_name: device_alias,
          object_type: 1,
          object_uuid: device_id
        })
        |> Repo.insert!(prefix: keyspace_name)
      end
    end

    old_introspection = %{{"com.test.LCDMonitor", 0} => 1}

    {:ok, device_id} = Astarte.Core.Device.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

    %DeviceSchema{}
    |> Ecto.Changeset.change(%{device_id: device_id, old_introspection: old_introspection})
    |> Repo.insert!(prefix: keyspace_name)

    kv_store_map = %{
      group: "auth",
      key: "jwt_public_key_pem",
      value: JWTTestHelper.public_key_pem()
    }

    KvStore.insert(kv_store_map, prefix: keyspace_name)

    %Interface{}
    |> Ecto.Changeset.change(%{
      name: "com.test.LCDMonitor",
      major_version: 1,
      automaton_accepting_states:
        Base.decode64!(
          "g3QAAAAFYQNtAAAAEIAeEDVf33Bpjm4/0nkmmathBG0AAAAQjrtis2DBS6JBcp3e3YCcn2EFbQAAABBP5QNKPZuZ7H7DsjcWMD0zYQdtAAAAEOb3NjHv/B1+rVLT86O65QthCG0AAAAQKyxj3bvZVzVtSo5W9QTt2g=="
        ),
      automaton_transitions:
        Base.decode64!(
          "g3QAAAAIaAJhAG0AAAAKbGNkQ29tbWFuZGEFaAJhAG0AAAAEdGltZWEGaAJhAG0AAAAMd2Vla1NjaGVkdWxlYQFoAmEBbQAAAABhAmgCYQJtAAAABXN0YXJ0YQNoAmECbQAAAARzdG9wYQRoAmEGbQAAAARmcm9tYQdoAmEGbQAAAAJ0b2EI"
        ),
      aggregation: :individual,
      interface_id: "798b93a5-842e-bbad-2e4d-d20306838051",
      minor_version: 3,
      ownership: :device,
      storage: "individual_properties",
      storage_type: :multi_interface_individual_properties_dbtable,
      type: :properties
    })
    |> Repo.insert!(prefix: keyspace_name)

    %Interface{}
    |> Ecto.Changeset.change(%{
      name: "com.test.SimpleStreamTest",
      major_version: 1,
      automaton_accepting_states:
        Base.decode64!(
          "g3QAAAAFYQJtAAAAEHUBDhsZnu783TXSVLDiCSRhBW0AAAAQOQfUHVvKMp2eUUzqKlSpmmEGbQAAABB6pEwRInNH2eYkSuAp3t6qYQdtAAAAEO/5V88D397tl4SocI49jLlhCG0AAAAQNGyA5MqZYnSB9nscG+WVIQ=="
        ),
      automaton_transitions:
        Base.decode64!(
          "g3QAAAAIaAJhAG0AAAAAYQFoAmEAbQAAAANmb29hA2gCYQFtAAAABXZhbHVlYQJoAmEDbQAAAABhBGgCYQRtAAAACWJsb2JWYWx1ZWEGaAJhBG0AAAAJbG9uZ1ZhbHVlYQdoAmEEbQAAAAtzdHJpbmdWYWx1ZWEFaAJhBG0AAAAOdGltZXN0YW1wVmFsdWVhCA=="
        ),
      aggregation: :individual,
      interface_id: "0a0da77d-85b5-93d9-d4d2-bd26dd18c9af",
      minor_version: 0,
      ownership: :device,
      storage: "individual_datastreams",
      storage_type: :multi_interface_individual_datastream_dbtable,
      type: :datastream
    })
    |> Repo.insert!(prefix: keyspace_name)

    %Interface{}
    |> Ecto.Changeset.change(%{
      name: "com.example.TestObject",
      major_version: 1,
      automaton_accepting_states:
        Base.decode64!("g3QAAAACYQFtAAAAEHyfFOhPL5d/wSbV4buYdudhAm0AAAAQOzn9OuJhJv/lI0wt0VC4ZA=="),
      automaton_transitions:
        Base.decode64!("g3QAAAACaAJhAG0AAAAGc3RyaW5nYQFoAmEAbQAAAAV2YWx1ZWEC"),
      aggregation: :object,
      interface_id: "db576345-80b1-5358-f305-d77ec39b3d84",
      minor_version: 5,
      ownership: :device,
      storage: "com_example_testobject_v1",
      storage_type: :one_object_datastream_dbtable,
      type: :datastream
    })
    |> Repo.insert!(prefix: keyspace_name)

    %Interface{}
    |> Ecto.Changeset.change(%{
      name: "com.example.PixelsConfiguration",
      major_version: 1,
      automaton_accepting_states: Base.decode64!("g3QAAAABYQNtAAAAEOPZVKNVUNqw17mW3O0hiYc="),
      automaton_transitions:
        Base.decode64!("g3QAAAADaAJhAG0AAAAAYQFoAmEBbQAAAABhAmgCYQJtAAAABWNvbG9yYQM="),
      aggregation: :individual,
      interface_id: "9651f167-a619-3ff5-1c4e-6771fb1929d4",
      minor_version: 0,
      ownership: :server,
      storage: "individual_properties",
      storage_type: :multi_interface_individual_properties_dbtable,
      type: :properties
    })
    |> Repo.insert!(prefix: keyspace_name)

    %Interface{}
    |> Ecto.Changeset.change(%{
      name: "com.example.ServerOwnedTestObject",
      major_version: 1,
      automaton_accepting_states:
        Base.decode64!("g3QAAAACYQJtAAAAEIHahvd6V6DBzoQ2NREFi/hhA20AAAAQO5N/Tn43gvexm3JE6PUw1Q=="),
      automaton_transitions:
        Base.decode64!("g3QAAAADaAJhAG0AAAAAYQFoAmEBbQAAAAZzdHJpbmdhAmgCYQFtAAAABXZhbHVlYQM="),
      aggregation: :object,
      interface_id: "f0deb891-a02d-19db-ce8e-e8ed82c45587",
      minor_version: 0,
      ownership: :server,
      storage: "com_example_testobject_v1",
      storage_type: :one_object_datastream_dbtable,
      type: :datastream
    })
    |> Repo.insert!(prefix: keyspace_name)

    Enum.each(@insert_endpoints, fn query ->
      Repo.query!(query)
    end)

    Enum.each(@insert_values, fn query ->
      Repo.query!(query)
    end)

    for {encoded_device_id, _, _, _, _, _} <- @devices_list,
        encoded_device_id == "ehNpbPVtQ2CcdJdJK3QUlA" do
      {:ok, device_id} = Device.decode_device_id(encoded_device_id)
      insert_device_into_deletion_in_progress(device_id)
    end

    :ok
  end

  def fake_connect_device(encoded_device_id, connected) when is_boolean(connected) do
    {:ok, device_id} = Astarte.Core.Device.decode_device_id(encoded_device_id)

    Xandra.Cluster.run(:xandra, fn conn ->
      query = """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.devices
      (device_id, connected) VALUES (:device_id, :connected)
      """

      params = %{"device_id" => device_id, "connected" => connected}
      prepared = Xandra.prepare!(conn, query)
      %Xandra.Void{} = Xandra.execute!(conn, prepared, params)
    end)

    :ok
  end

  def create_datastream_receiving_device do
    insert_datastream_receiving_device()
    insert_datastream_receiving_device_endpoints()
    insert_into_interface_datastream()
  end

  defp insert_datastream_receiving_device do
    keyspace_name = Realm.keyspace_name(@test_realm)

    {:ok, device_id} = Astarte.Core.Device.decode_device_id("fmloLzG5T5u0aOUfIkL8KA")

    %DeviceSchema{}
    |> Ecto.Changeset.change(%{
      device_id: device_id,
      aliases: %{"display_name" => "receiving_device"},
      attributes: %{"device_attribute_key" => "device_attribute_value"},
      connected: false,
      last_connection: ~U[2020-02-11 04:05:00Z],
      last_disconnection: ~U[2020-02-10 04:05:00Z],
      first_registration: ~U[2016-08-15 11:05:00Z],
      first_credentials_request: ~U[2016-08-20 11:05:00Z],
      last_seen_ip: :inet.parse_address(~c"198.51.100.81") |> elem(1),
      last_credentials_request_ip: :inet.parse_address(~c"198.51.100.89") |> elem(1),
      total_received_msgs: 22000,
      total_received_bytes: 246,
      inhibit_credentials_request: false,
      introspection: %{"org.ServerOwnedIndividual" => 0},
      introspection_minor: %{"org.ServerOwnedIndividual" => 1},
      exchanged_msgs_by_interface: %{{"org.ServerOwnedIndividual", 0} => 16},
      exchanged_bytes_by_interface: %{{"org.ServerOwnedIndividual", 0} => 1024}
    })
    |> Repo.insert!(prefix: keyspace_name)
  end

  defp insert_datastream_receiving_device_endpoints() do
    keyspace_name = Realm.keyspace_name(@test_realm)

    %EndpointSchema{}
    |> Ecto.Changeset.change(%{
      interface_id: "13ccc31d-f911-29df-cbe6-be22635293bd",
      endpoint_id: "44c2421d-1abf-f3ec-14e1-986928d764aa",
      allow_unset: false,
      endpoint: "/%{sensor_id}/samplingPeriod",
      expiry: 0,
      interface_major_version: 0,
      interface_minor_version: 1,
      interface_name: "org.ServerOwnedIndividual",
      interface_type: :datastream,
      reliability: :unique,
      retention: :discard,
      value_type: :integer
    })
    |> Repo.insert!(prefix: keyspace_name)
  end

  defp insert_into_interface_datastream() do
    keyspace_name = Realm.keyspace_name(@test_realm)

    %Interface{}
    |> Ecto.Changeset.change(%{
      name: "org.ServerOwnedIndividual",
      major_version: 0,
      automaton_accepting_states:
        "83740000000161026d0000001044c2421d1abff3ec14e1986928d764aa"
        |> Base.decode16!(case: :lower),
      automaton_transitions:
        "837400000002680261006d000000006101680261016d0000000e73616d706c696e67506572696f646102"
        |> Base.decode16!(case: :lower),
      aggregation: :individual,
      interface_id: "13ccc31d-f911-29df-cbe6-be22635293bd",
      minor_version: 1,
      ownership: :server,
      storage: "individual_datastreams",
      storage_type: :multi_interface_individual_datastream_dbtable,
      type: :datastream
    })
    |> Repo.insert!(prefix: keyspace_name)
  end

  def remove_datastream_receiving_device do
    keyspace_name = Realm.keyspace_name(@test_realm)

    {:ok, device_id} = Astarte.Core.Device.decode_device_id("fmloLzG5T5u0aOUfIkL8KA")

    {:ok, interface_id} = Astarte.DataAccess.UUID.cast("13ccc31d-f911-29df-cbe6-be22635293bd")

    Repo.delete_all(
      from d in DeviceSchema,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id
    )

    Repo.delete_all(
      from e in EndpointSchema,
        prefix: ^keyspace_name,
        where: e.interface_id == ^interface_id
    )

    Repo.delete_all(
      from i in Interface,
        prefix: ^keyspace_name,
        where: i.name == "org.ServerOwnedIndividual"
    )
  end

  def create_object_receiving_device do
    insert_object_receiving_device()
    create_server_owned_aggregated_object_table()
    insert_object_receiving_device_endpoints()
    insert_into_interface_obj_aggregated()
  end

  defp insert_object_receiving_device_endpoints() do
    insert_endpoint_queries = [
      """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints(interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
      (65c96ecb-f2d5-b440-4840-16cd84d2c2be, 76c99541-dd31-6369-bcdd-f2fdacc2d3ff, False, '/%{sensor_id}/enable', 0, 0, 1, 'org.astarte-platform.genericsensors.ServerOwnedAggregateObj', 2, 3, 1, 9);
      """,
      """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints(interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
      (65c96ecb-f2d5-b440-4840-16cd84d2c2be, 6ebd007e-dd74-8e32-f032-78d433b1b8e7, False, '/%{sensor_id}/samplingPeriod', 0, 0, 1, 'org.astarte-platform.genericsensors.ServerOwnedAggregateObj', 2, 3, 1, 3);
      """,
      """
      INSERT INTO #{Realm.keyspace_name(@test_realm)}.endpoints(interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
      (65c96ecb-f2d5-b440-4840-16cd84d2c2be, d42c4f4f-6faa-3f37-b38f-74602e7aec7d, False, '/%{sensor_id}/binaryblobarray', 0, 0, 1, 'org.astarte-platform.genericsensors.ServerOwnedAggregateObj', 2, 3, 1, 12);
      """
    ]

    Enum.each(insert_endpoint_queries, fn query ->
      Repo.query!(query)
    end)
  end

  defp insert_into_interface_obj_aggregated() do
    keyspace_name = Realm.keyspace_name(@test_realm)

    %Interface{}
    |> Ecto.Changeset.change(%{
      name: "org.astarte-platform.genericsensors.ServerOwnedAggregateObj",
      major_version: 0,
      automaton_accepting_states:
        "83740000000361026d0000001076c99541dd316369bcddf2fdacc2d3ff61036d000000106ebd007edd748e32f03278d433b1b8e761046d00000010d42c4f4f6faa3f37b38f74602e7aec7d"
        |> Base.decode16!(case: :lower),
      automaton_transitions:
        "837400000004680261006d000000006101680261016d0000000f62696e617279626c6f6261727261796104680261016d00000006656e61626c656102680261016d0000000e73616d706c696e67506572696f646103"
        |> Base.decode16!(case: :lower),
      aggregation: :object,
      interface_id: "65c96ecb-f2d5-b440-4840-16cd84d2c2be",
      minor_version: 1,
      ownership: :server,
      storage: "com_example_server_owned_aggregated_object_v1",
      storage_type: :one_object_datastream_dbtable,
      type: :datastream
    })
    |> Repo.insert!(prefix: keyspace_name)
  end

  defp create_server_owned_aggregated_object_table() do
    create_server_owned_aggregated_object_table_query = """
    CREATE TABLE IF NOT EXISTS #{Realm.keyspace_name(@test_realm)}.com_example_server_owned_aggregated_object_v1 (
    device_id uuid,
    path varchar,
    reception_timestamp timestamp,
    reception_timestamp_submillis smallint,
    v_enable boolean,
    v_samplingPeriod int,
    v_binaryblobarray list<blob>,
    PRIMARY KEY ((device_id, path), reception_timestamp, reception_timestamp_submillis));
    """

    Repo.query!(create_server_owned_aggregated_object_table_query)
  end

  defp insert_object_receiving_device() do
    keyspace_name = Realm.keyspace_name(@test_realm)

    {:ok, device_id} = Astarte.Core.Device.decode_device_id("fmloLzG5T5u0aOUfIkL8KA")

    %DeviceSchema{}
    |> Ecto.Changeset.change(%{
      device_id: device_id,
      aliases: %{"display_name" => "receiving_device"},
      attributes: %{"obj_attribute_key" => "obj_attribute_value"},
      connected: false,
      last_connection: ~U[2020-02-11 04:05:00Z],
      last_disconnection: ~U[2020-02-10 04:05:00Z],
      first_registration: ~U[2016-08-15 11:05:00Z],
      first_credentials_request: ~U[2016-08-20 11:05:00Z],
      last_seen_ip: {198, 51, 100, 81},
      last_credentials_request_ip: {198, 51, 100, 59},
      total_received_msgs: 45000,
      total_received_bytes: 1234,
      inhibit_credentials_request: false,
      introspection: %{"org.astarte-platform.genericsensors.ServerOwnedAggregateObj" => 0},
      introspection_minor: %{"org.astarte-platform.genericsensors.ServerOwnedAggregateObj" => 1},
      exchanged_msgs_by_interface: %{
        {"org.astarte-platform.genericsensors.ServerOwnedAggregateObj", 0} => 16
      },
      exchanged_bytes_by_interface: %{
        {"org.astarte-platform.genericsensors.ServerOwnedAggregateObj", 0} => 1024
      }
    })
    |> Repo.insert!(prefix: keyspace_name)
  end

  def remove_object_receiving_device do
    keyspace_name = Realm.keyspace_name(@test_realm)
    {:ok, device_id} = Astarte.Core.Device.decode_device_id("fmloLzG5T5u0aOUfIkL8KA")

    Repo.delete_all(
      from d in DeviceSchema,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id
    )

    query =
      "DROP TABLE #{Realm.keyspace_name(@test_realm)}.com_example_server_owned_aggregated_object_v1;"

    Repo.query!(query)

    interface_id = "65c96ecb-f2d5-b440-4840-16cd84d2c2be"

    Repo.delete_all(
      from e in EndpointSchema,
        prefix: ^keyspace_name,
        where: e.interface_id == ^interface_id
    )

    Repo.delete_all(
      from i in Interface,
        prefix: ^keyspace_name,
        where: i.name == "org.astarte-platform.genericsensors.ServerOwnedAggregateObj"
    )
  end

  def set_realm_ttl(ttl_s) do
    keyspace_name = Realm.keyspace_name(@test_realm)

    params = %{
      group: "realm_config",
      key: "datastream_maximum_storage_retention",
      value: ttl_s,
      value_type: :integer
    }

    KvStore.insert(params, prefix: keyspace_name)
  end

  def unset_realm_ttl do
    keyspace_name = Realm.keyspace_name(@test_realm)

    Repo.delete_all(
      from k in KvStore,
        prefix: ^keyspace_name,
        where: k.group == "realm_config" and k.key == "datastream_maximum_storage_retention"
    )
  end

  def devices_count do
    length(@devices_list)
  end

  def destroy_local_test_keyspace do
    delete_query = """
      DROP KEYSPACE #{Realm.keyspace_name(@test_realm)};
    """

    Repo.query(delete_query)

    :ok
  end
end
