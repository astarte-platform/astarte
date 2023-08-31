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
#

defmodule Astarte.DataUpdaterPlant.DatabaseTestHelper do
  alias Astarte.DataUpdaterPlant.TriggerPolicy.Queries
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils, as: SimpleTriggersProtobufUtils
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries

  @create_autotestrealm """
    CREATE KEYSPACE autotestrealm
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """

  @create_devices_table """
      CREATE TABLE autotestrealm.devices (
        device_id uuid,
        introspection map<ascii, int>,
        introspection_minor map<ascii, int>,
        old_introspection map<frozen<tuple<ascii, int>>, int>,
        protocol_revision int,
        triggers set<ascii>,
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
        exchanged_bytes_by_interface map<frozen<tuple<ascii, int>>, bigint>,
        exchanged_msgs_by_interface map<frozen<tuple<ascii, int>>, bigint>,
        last_pairing_ip inet,
        last_seen_ip inet,
        groups map<text, timeuuid>,

        PRIMARY KEY (device_id)
    );
  """

  @insert_device """
        INSERT INTO autotestrealm.devices (device_id, connected, last_connection, last_disconnection, first_pairing, last_seen_ip, last_pairing_ip, total_received_msgs, total_received_bytes, introspection, groups)
          VALUES (:device_id, false, :last_connection, :last_disconnection, :first_pairing,
          :last_seen_ip, :last_pairing_ip, :total_received_msgs, :total_received_bytes, :introspection, :groups);
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
        ownership int,
        aggregation int,
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

  @create_simple_triggers_table """
      CREATE TABLE autotestrealm.simple_triggers (
        object_id uuid,
        object_type int,
        parent_trigger_id uuid,
        simple_trigger_id uuid,
        trigger_data blob,
        trigger_target blob,

        PRIMARY KEY ((object_id, object_type), parent_trigger_id, simple_trigger_id)
      );
  """

  @create_kv_store_table """
      CREATE TABLE autotestrealm.kv_store (
        group varchar,
        key varchar,
        value blob,

        PRIMARY KEY ((group), key)
      );
  """

  @insert_endpoints [
    """
      INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, e6f73631-effc-1d7e-ad52-d3f3a3bae50b, False, '/time/from', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 2b2c63dd-bbd9-5735-6d4a-8e56f504edda, False, '/time/to', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, False, '/weekSchedule/%{day}/start', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 4fe5034a-3d9b-99ec-7ec3-b23716303d33, False, '/lcdCommand', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 7);
    """,
    """
      INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, False, '/weekSchedule/%{day}/stop', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, False, '/%{itemIndex}/value', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 3);
    """,
    """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 3907d41d-5bca-329d-9e51-4cea2a54a99a, False, '/foo/%{param}/stringValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 7);
    """,
    """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 7aa44c11-2273-47d9-e624-4ae029dedeaa, False, '/foo/%{param}/blobValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 11);
    """,
    """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, eff957cf-03df-deed-9784-a8708e3d8cb9, False, '/foo/%{param}/longValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 5);
    """,
    """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 346c80e4-ca99-6274-81f6-7b1c1be59521, False, '/foo/%{param}/timestampValue', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 13);
    """,
    """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (db576345-80b1-5358-f305-d77ec39b3d84, 7c9f14e8-4f2f-977f-c126-d5e1bb9876e7, False, '/string', 0, 1, 5, 'com.example.TestObject', 2, 2, 3, 7);
    """,
    """
    INSERT INTO autotestrealm.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (db576345-80b1-5358-f305-d77ec39b3d84, 3b39fd3a-e261-26ff-e523-4c2dd150b864, False, '/value', 0, 1, 5, 'com.example.TestObject', 2, 2, 3, 1);
    """
  ]

  @create_individual_properties_table """
    CREATE TABLE IF NOT EXISTS autotestrealm.individual_properties (
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
    CREATE TABLE IF NOT EXISTS autotestrealm.individual_datastreams (
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
    CREATE TABLE autotestrealm.com_example_testobject_v1 (
      device_id uuid,
      path varchar,

      reception_timestamp timestamp,
      reception_timestamp_submillis smallint,
      v_string varchar,
      v_value double,
      PRIMARY KEY ((device_id, path), reception_timestamp, reception_timestamp_submillis)
    );
  """

  @insert_values [
    """
      INSERT INTO autotestrealm.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, e6f73631-effc-1d7e-ad52-d3f3a3bae50b, '/time/from', 8);
    """,
    """
      INSERT INTO autotestrealm.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 2b2c63dd-bbd9-5735-6d4a-8e56f504edda, '/time/to', 20);
    """,
    """
      INSERT INTO autotestrealm.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/2/start', 12);
    """,
    """
      INSERT INTO autotestrealm.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/3/start', 15);
    """,
    """
      INSERT INTO autotestrealm.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/4/start', 16);
    """,
    """
      INSERT INTO autotestrealm.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/10/start', 42);
    """,
    """
      INSERT INTO autotestrealm.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/2/stop', 15);
    """,
    """
      INSERT INTO autotestrealm.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/3/stop', 16);
    """,
    """
      INSERT INTO autotestrealm.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/4/stop', 18);
    """,
    """
      INSERT INTO autotestrealm.individual_properties (device_id, interface_id, endpoint_id, path, string_value) VALUES
       (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 4fe5034a-3d9b-99ec-7ec3-b23716303d33, '/lcdCommand', 'SWITCH_ON');
    """,
    """
      INSERT INTO autotestrealm.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:05+0000', '2017-09-28 05:05+0000', 0, 0);
    """,
    """
      INSERT INTO autotestrealm.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:06+0000', '2017-09-28 05:06+0000', 0, 1);
    """,
    """
      INSERT INTO autotestrealm.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:07+0000', '2017-09-28 05:07+0000', 0, 2);
    """,
    """
      INSERT INTO autotestrealm.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-29 05:07+0000', '2017-09-29 06:07+0000', 0, 3);
    """,
    """
      INSERT INTO autotestrealm.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-30 07:10+0000', '2017-09-30 08:10+0000', 0, 4);
    """,
    """
      INSERT INTO autotestrealm.com_example_testobject_v1 (device_id, path, reception_timestamp, reception_timestamp_submillis, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:10+0000', 0, 1.1, 'aaa');
    """,
    """
      INSERT INTO autotestrealm.com_example_testobject_v1 (device_id, path, reception_timestamp, reception_timestamp_submillis, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:12+0000', 0, 2.2, 'bbb');
    """,
    """
      INSERT INTO autotestrealm.com_example_testobject_v1 (device_id, path, reception_timestamp, reception_timestamp_submillis, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:13+0000', 0, 3.3, 'ccc');
    """
  ]

  @insert_into_interface_0 """
  INSERT INTO autotestrealm.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, aggregation, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
    ('com.test.LCDMonitor', 1, :automaton_accepting_states, :automaton_transitions, 1, 798b93a5-842e-bbad-2e4d-d20306838051, 3, 1, 'individual_properties', 1, 1)
  """

  @insert_into_interface_1 """
  INSERT INTO autotestrealm.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, aggregation, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
    ('com.test.SimpleStreamTest', 1, :automaton_accepting_states, :automaton_transitions, 1, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 0, 1, 'individual_datastreams', 2, 2)
  """

  @insert_into_interface_2 """
  INSERT INTO autotestrealm.interfaces (name, major_version, automaton_accepting_states, automaton_transitions, aggregation, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
    ('com.example.TestObject', 1, :automaton_accepting_states, :automaton_transitions, 2, db576345-80b1-5358-f305-d77ec39b3d84, 5, 1, 'com_example_testobject_v1', 5, 2)
  """

  @insert_into_simple_triggers """
  INSERT INTO autotestrealm.simple_triggers (object_id, object_type, parent_trigger_id, simple_trigger_id, trigger_data, trigger_target)
  VALUES (:object_id, :object_type, :parent_trigger_id, :simple_trigger_id, :trigger_data, :trigger_target);
  """

  def create_test_keyspace! do
    Queries.custom_query!(@create_autotestrealm)
    Queries.custom_query!(@create_devices_table)
    Queries.custom_query!(@create_endpoints_table)

    @insert_endpoints
    |> Enum.each(&Queries.custom_query!/1)

    Queries.custom_query!(@create_simple_triggers_table)
    Queries.custom_query!(@create_individual_properties_table)
    Queries.custom_query!(@create_individual_datastreams_table)
    Queries.custom_query!(@create_test_object_table)

    @insert_values
    |> Enum.each(&Queries.custom_query!/1)

    Queries.custom_query!(@create_interfaces_table)
    Queries.custom_query!(@create_kv_store_table)

    params_interface_0 = %{
      "automaton_accepting_states" =>
        Base.decode64!(
          "g3QAAAAFYQNtAAAAEIAeEDVf33Bpjm4/0nkmmathBG0AAAAQjrtis2DBS6JBcp3e3YCcn2EFbQAAABBP5QNKPZuZ7H7DsjcWMD0zYQdtAAAAEOb3NjHv/B1+rVLT86O65QthCG0AAAAQKyxj3bvZVzVtSo5W9QTt2g=="
        ),
      "automaton_transitions" =>
        Base.decode64!(
          "g3QAAAAIaAJhAG0AAAAKbGNkQ29tbWFuZGEFaAJhAG0AAAAEdGltZWEGaAJhAG0AAAAMd2Vla1NjaGVkdWxlYQFoAmEBbQAAAABhAmgCYQJtAAAABXN0YXJ0YQNoAmECbQAAAARzdG9wYQRoAmEGbQAAAARmcm9tYQdoAmEGbQAAAAJ0b2EI"
        )
    }

    params_interface_1 = %{
      "automaton_accepting_states" =>
        Base.decode64!(
          "g3QAAAAFYQJtAAAAEHUBDhsZnu783TXSVLDiCSRhBW0AAAAQOQfUHVvKMp2eUUzqKlSpmmEGbQAAABB6pEwRInNH2eYkSuAp3t6qYQdtAAAAEO/5V88D397tl4SocI49jLlhCG0AAAAQNGyA5MqZYnSB9nscG+WVIQ=="
        ),
      "automaton_transitions" =>
        Base.decode64!(
          "g3QAAAAIaAJhAG0AAAAAYQFoAmEAbQAAAANmb29hA2gCYQFtAAAABXZhbHVlYQJoAmEDbQAAAABhBGgCYQRtAAAACWJsb2JWYWx1ZWEGaAJhBG0AAAAJbG9uZ1ZhbHVlYQdoAmEEbQAAAAtzdHJpbmdWYWx1ZWEFaAJhBG0AAAAOdGltZXN0YW1wVmFsdWVhCA=="
        )
    }

    params_interface_2 = %{
      "automaton_accepting_states" =>
        Base.decode64!("g3QAAAACYQFtAAAAEHyfFOhPL5d/wSbV4buYdudhAm0AAAAQOzn9OuJhJv/lI0wt0VC4ZA=="),
      "automaton_transitions" =>
        Base.decode64!("g3QAAAACaAJhAG0AAAAGc3RyaW5nYQFoAmEAbQAAAAV2YWx1ZWEC")
    }

    Queries.custom_query(@insert_into_interface_0, nil, params_interface_0)

    Queries.custom_query(@insert_into_interface_1, nil, params_interface_1)

    Queries.custom_query(@insert_into_interface_2, nil, params_interface_2)

    simple_trigger_data =
      %Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger{
            interface_name: "com.test.LCDMonitor",
            interface_major: 1,
            data_trigger_type: :INCOMING_DATA,
            match_path: "/weekSchedule/%{weekDay}/start",
            value_match_operator: :GREATER_THAN,
            known_value: Cyanide.encode!(%{v: 9})
          }
        }
      }
      |> Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer.encode()

    trigger_target_data =
      %Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer.encode()

    params = %{
      "object_id" => :uuid.string_to_uuid("798b93a5-842e-bbad-2e4d-d20306838051"),
      "object_type" => SimpleTriggersProtobufUtils.object_type_to_int!(:interface),
      "simple_trigger_id" => greater_than_incoming_trigger_id(),
      "parent_trigger_id" => fake_parent_trigger_id(),
      "trigger_data" => simple_trigger_data,
      "trigger_target" => trigger_target_data
    }

    Queries.custom_query!(@insert_into_simple_triggers, nil, params)

    simple_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :device_trigger,
          %DeviceTrigger{
            device_event_type: :DEVICE_CONNECTED
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    trigger_target_data =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    params = %{
      "object_id" => :uuid.string_to_uuid("7f454c46-0201-0100-0000-000000000000"),
      "object_type" => SimpleTriggersProtobufUtils.object_type_to_int!(:device),
      "simple_trigger_id" => device_connected_trigger_id(),
      "parent_trigger_id" => fake_parent_trigger_id(),
      "trigger_data" => simple_trigger_data,
      "trigger_target" => trigger_target_data
    }

    Queries.custom_query!(@insert_into_simple_triggers, nil, params)

    simple_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %DataTrigger{
            interface_name: "com.test.LCDMonitor",
            interface_major: 1,
            data_trigger_type: :PATH_REMOVED,
            match_path: "/time/from"
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    trigger_target_data =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    params = %{
      "object_id" => :uuid.string_to_uuid("798b93a5-842e-bbad-2e4d-d20306838051"),
      "object_type" => SimpleTriggersProtobufUtils.object_type_to_int!(:interface),
      "simple_trigger_id" => path_removed_trigger_id(),
      "parent_trigger_id" => fake_parent_trigger_id(),
      "trigger_data" => simple_trigger_data,
      "trigger_target" => trigger_target_data
    }

    Queries.custom_query!(@insert_into_simple_triggers, nil, params)

    # group 1 device trigger
    simple_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :device_trigger,
          %DeviceTrigger{
            device_event_type: :DEVICE_CONNECTED,
            group_name: "group1"
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    trigger_target_data =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    object_id = SimpleTriggersProtobufUtils.get_group_object_id("group1")

    group_1_params = %{
      "object_id" => object_id,
      "object_type" => SimpleTriggersProtobufUtils.object_type_to_int!(:group),
      "simple_trigger_id" => group1_device_connected_trigger_id(),
      "parent_trigger_id" => fake_parent_trigger_id(),
      "trigger_data" => simple_trigger_data,
      "trigger_target" => trigger_target_data
    }

    Queries.custom_query!(@insert_into_simple_triggers, nil, group_1_params)

    # group 2 device trigger
    simple_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :device_trigger,
          %DeviceTrigger{
            device_event_type: :DEVICE_CONNECTED,
            group_name: "group2"
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    trigger_target_data =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    object_id = SimpleTriggersProtobufUtils.get_group_object_id("group2")

    group_2_params = %{
      "object_id" => object_id,
      "object_type" => SimpleTriggersProtobufUtils.object_type_to_int!(:group),
      "simple_trigger_id" => group2_device_connected_trigger_id(),
      "parent_trigger_id" => fake_parent_trigger_id(),
      "trigger_data" => simple_trigger_data,
      "trigger_target" => trigger_target_data
    }

    Queries.custom_query!(@insert_into_simple_triggers, nil, group_2_params)

    # Device-specific data trigger

    target_device_id = "f0VMRgIBAQAAAAAAAAAAAA"

    simple_trigger_data =
      %Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger{
            device_id: target_device_id,
            interface_name: "com.test.LCDMonitor",
            interface_major: 1,
            data_trigger_type: :INCOMING_DATA,
            match_path: "/weekSchedule/%{weekDay}/start",
            value_match_operator: :LESS_THAN,
            known_value: Cyanide.encode!(%{v: 2})
          }
        }
      }
      |> Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer.encode()

    trigger_target_data =
      %Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer.encode()

    {:ok, target_decoded_device_id} = target_device_id |> Device.decode_device_id()

    interface_id = CQLUtils.interface_id("com.test.LCDMonitor", 1)

    object_id =
      SimpleTriggersProtobufUtils.get_device_and_interface_object_id(
        target_decoded_device_id,
        interface_id
      )

    device_params = %{
      "object_id" => object_id,
      "object_type" => SimpleTriggersProtobufUtils.object_type_to_int!(:device_and_interface),
      "simple_trigger_id" => less_than_device_incoming_trigger_id(),
      "parent_trigger_id" => fake_parent_trigger_id(),
      "trigger_data" => simple_trigger_data,
      "trigger_target" => trigger_target_data
    }

    Queries.custom_query!(@insert_into_simple_triggers, nil, device_params)

    # Group-specific data trigger
    target_group = "group1"

    simple_trigger_data =
      %Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger{
            group_name: target_group,
            interface_name: "com.test.LCDMonitor",
            interface_major: 1,
            data_trigger_type: :INCOMING_DATA,
            match_path: "/weekSchedule/%{weekDay}/start",
            value_match_operator: :EQUAL_TO,
            known_value: Cyanide.encode!(%{v: 3})
          }
        }
      }
      |> Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer.encode()

    trigger_target_data =
      %Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer.encode()

    interface_id = CQLUtils.interface_id("com.test.LCDMonitor", 1)

    object_id =
      SimpleTriggersProtobufUtils.get_group_and_interface_object_id(
        target_group,
        interface_id
      )

    group_specific_params = %{
      "object_id" => object_id,
      "object_type" => SimpleTriggersProtobufUtils.object_type_to_int!(:group_and_interface),
      "simple_trigger_id" => equal_to_group_incoming_trigger_id(),
      "parent_trigger_id" => fake_parent_trigger_id(),
      "trigger_data" => simple_trigger_data,
      "trigger_target" => trigger_target_data
    }

    Queries.custom_query!(@insert_into_simple_triggers, nil, group_specific_params)
  end

  def destroy_local_test_keyspace do
    Queries.custom_query("DROP KEYSPACE autotestrealm;")
    :ok
  end

  def insert_device(device_id, opts \\ []) do
    params =
      opts
      |> Keyword.validate!(
        last_connection: nil,
        last_disconnection: nil,
        first_pairing: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
        last_seen_ip: nil,
        last_pairing_ip: nil,
        total_received_msgs: 0,
        total_received_bytes: 0,
        introspection: %{},
        groups: []
      )
      |> Keyword.update!(:groups, &Map.new(&1, fn group -> {group, UUID.uuid1()} end))
      |> Keyword.put(:device_id, device_id)
      |> Map.new(fn {key, val} -> {to_string(key), val} end)

    Queries.custom_query(@insert_device, nil, params)
  end

  def fetch_old_introspection(realm, device_id) do
    old_introspection_statement = """
    SELECT old_introspection
    FROM devices
    WHERE device_id=:device_id
    """

    params = %{
      "device_id" => device_id
    }

    with {:ok, result} <-
           Queries.custom_query(old_introspection_statement, realm, params,
             consistency: :quorum,
             result: :first!
           ) do
      %{"old_introspection" => introspection_minors} = result
      introspection_minors = introspection_minors || %{}
      {:ok, introspection_minors}
    end
  end

  def fake_parent_trigger_id() do
    <<252, 187, 176, 47, 156, 161, 74, 169, 161, 197, 180, 56, 7, 115, 128, 207>>
  end

  def device_connected_trigger_id() do
    <<216, 12, 133, 232, 80, 173, 169, 7, 46, 113, 239, 216, 165, 193, 220, 33>>
  end

  def group1_device_connected_trigger_id() do
    <<182, 120, 174, 119, 245, 179, 155, 140, 4, 8, 11, 179, 198, 39, 108, 227>>
  end

  def group2_device_connected_trigger_id() do
    <<237, 137, 173, 250, 141, 190, 136, 30, 95, 127, 62, 188, 145, 4, 134, 154>>
  end

  def interface_added_trigger_id() do
    <<29, 75, 194, 112, 8, 190, 133, 129, 152, 38, 51, 180, 37, 93, 103, 33>>
  end

  def path_removed_trigger_id() do
    <<8, 107, 10, 96, 174, 205, 127, 187, 26, 141, 199, 195, 211, 61, 148, 174>>
  end

  def greater_than_incoming_trigger_id() do
    <<173, 82, 46, 100, 127, 143, 79, 136, 37, 210, 111, 73, 7, 24, 69, 130>>
  end

  def less_than_device_incoming_trigger_id() do
    <<186, 166, 108, 33, 121, 60, 44, 72, 206, 25, 165, 98, 144, 127, 142, 227>>
  end

  def equal_to_group_incoming_trigger_id() do
    <<140, 143, 242, 83, 113, 178, 249, 23, 213, 224, 46, 58, 138, 34, 20, 45>>
  end

  # TODO: include in astarte_data_access
  def await_cluster_connected!(cluster \\ nil, tries \\ 10) do
    cluster = cluster || Config.xandra_options!()[:name]
    fun = &Xandra.execute!(&1, "SELECT * FROM system.local")

    with {:error, %Xandra.ConnectionError{}} <- Xandra.Cluster.run(cluster, _options = [], fun) do
      if tries > 0 do
        Process.sleep(100)
        await_cluster_connected!(cluster, tries - 1)
      else
        raise("Connection to the cluster failed")
      end
    end
  end
end
