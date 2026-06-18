#
# This file is part of Astarte.
#
# Copyright 2017 - 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.Helpers.Database do
  @moduledoc """
  Database helper functions.
  """

  alias Astarte.Core.Device, as: DeviceCore
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.Name
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  @test_realm "autotestrealm"

  @create_keyspace """
  CREATE KEYSPACE :keyspace
    WITH
    replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
    durable_writes = true;
  """

  @create_capabilities_type """
  CREATE TYPE :keyspace.capabilities (
    purge_properties_compression_format int
  );
  """

  @create_session_key_type """
  CREATE TYPE :keyspace.session_key (
    alg int,
    k blob
  );
  """

  @create_ownership_vouchers_table """
  CREATE TABLE :keyspace.ownership_vouchers (
    guid blob,
    voucher_data blob,
    output_voucher blob,
    replacement_guid blob,
    replacement_rendezvous_info blob,
    replacement_public_key blob,
    key_name varchar,
    key_algorithm int,
    user_id blob,
    status int,
    PRIMARY KEY (guid)
  );
  """

  @create_to2_sessions_table """
  CREATE TABLE :keyspace.to2_sessions (
    guid blob,
    device_id uuid,
    hmac blob,
    nonce blob,
    sig_type int,
    epid_group blob,
    device_public_key blob,
    prove_dv_nonce blob,
    setup_dv_nonce blob,
    kex_suite_name ascii,
    cipher_suite_name int,
    max_owner_service_info_size int,
    owner_random blob,
    secret blob,
    sevk session_key,
    svk session_key,
    sek session_key,
    device_service_info map<tuple<text, text>, blob>,
    owner_service_info list<blob>,
    last_chunk_sent int,
    replacement_hmac blob,
    PRIMARY KEY (guid)
  )
  WITH default_time_to_live = 7200;
  """

  @create_realms_table """
  CREATE TABLE :keyspace.realms (
    realm_name varchar,
    device_registration_limit bigint,
    PRIMARY KEY (realm_name)
  );
  """

  @create_realms_1_1_0_table """
  CREATE TABLE :keyspace.realms (
    realm_name varchar,
    PRIMARY KEY (realm_name)
  );
  """

  @create_kv_store """
    CREATE TABLE :keyspace.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
  """

  @create_names_table """
    CREATE TABLE :keyspace.names (
      object_name varchar,
      object_type int,
      object_uuid uuid,

      PRIMARY KEY ((object_name), object_type)
    );
  """

  @create_simple_triggers_table """
    CREATE TABLE :keyspace.simple_triggers (
      object_id uuid,
      object_type int,
      parent_trigger_id uuid,
      simple_trigger_id uuid,
      trigger_data blob,
      trigger_target blob,

      PRIMARY KEY ((object_id, object_type), parent_trigger_id, simple_trigger_id)
    );
  """

  @create_grouped_devices_table """
    CREATE TABLE :keyspace.grouped_devices (
      group_name varchar,
      insertion_uuid timeuuid,
      device_id uuid,

      PRIMARY KEY ((group_name), insertion_uuid, device_id)
    );
  """

  @create_deletion_in_progress_table """
    CREATE TABLE :keyspace.deletion_in_progress (
      device_id uuid,
      vmq_ack boolean,
      dup_start_ack boolean,
      dup_end_ack boolean,
      groups set<text>,

      PRIMARY KEY (device_id)
    );
  """

  @create_devices_table """
      CREATE TABLE :keyspace.devices (
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
        groups map<varchar, timeuuid>,
        capabilities capabilities,

        PRIMARY KEY (device_id)
      );
  """

  @create_devices_1_1_0_table """
      CREATE TABLE :keyspace.devices (
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

  @create_interfaces_table """
      CREATE TABLE :keyspace.interfaces (
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
      CREATE TABLE :keyspace.endpoints (
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
        required boolean,

        PRIMARY KEY ((interface_id), endpoint_id)
      );
  """

  @create_endpoints_1_1_0_table """
      CREATE TABLE :keyspace.endpoints (
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

  @create_individual_properties_table """
    CREATE TABLE :keyspace.individual_properties (
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
      encryptedblob_value blob,
      encrypted_dek blob,

      PRIMARY KEY((device_id, interface_id), endpoint_id, path)
    );
  """

  @create_individual_properties_1_1_0_table """
    CREATE TABLE :keyspace.individual_properties (
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
    CREATE TABLE IF NOT EXISTS :keyspace.individual_datastreams (
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
      encryptedblob_value blob,
      encrypted_dek blob,

      PRIMARY KEY((device_id, interface_id, endpoint_id, path), value_timestamp, reception_timestamp, reception_timestamp_submillis)
    );
  """

  @create_test_object_table """
    CREATE TABLE :keyspace.com_example_testobject_v1 (
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
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, e6f73631-effc-1d7e-ad52-d3f3a3bae50b, '/time/from', 8);
    """,
    """
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 2b2c63dd-bbd9-5735-6d4a-8e56f504edda, '/time/to', 20);
    """,
    """
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/2/start', 12);
    """,
    """
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/3/start', 15);
    """,
    """
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, '/weekSchedule/4/start', 16);
    """,
    """
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/2/stop', 15);
    """,
    """
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/3/stop', 16);
    """,
    """
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, longinteger_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, '/weekSchedule/4/stop', 18);
    """,
    """
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, string_value) VALUES
       (7f454c46-0201-0100-0000-000000000000, 798b93a5-842e-bbad-2e4d-d20306838051, 4fe5034a-3d9b-99ec-7ec3-b23716303d33, '/lcdCommand', 'SWITCH_ON');
    """,
    """
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, reception_timestamp, reception_timestamp_submillis, datetime_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-30 07:10+0000', 0, '2017-09-30 07:11+0000');
    """,
    """
      INSERT INTO :keyspace.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:05+0000', '2017-09-28 05:05+0000', 0, 0);
    """,
    """
      INSERT INTO :keyspace.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:06+0000', '2017-09-28 05:06+0000', 0, 1);
    """,
    """
      INSERT INTO :keyspace.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-28 04:07+0000', '2017-09-28 05:07+0000', 0, 2);
    """,
    """
      INSERT INTO :keyspace.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-29 05:07+0000', '2017-09-29 06:07+0000', 0, 3);
    """,
    """
      INSERT INTO :keyspace.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value) VALUES
        (7f454c46-0201-0100-0000-000000000000, 0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, '/0/value', '2017-09-30 07:10+0000', '2017-09-30 08:10+0000', 0, 4);
    """,
    """
      INSERT INTO :keyspace.com_example_testobject_v1 (device_id, path, reception_timestamp, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:10+0000', 1.1, 'aaa');
    """,
    """
      INSERT INTO :keyspace.com_example_testobject_v1 (device_id, path, reception_timestamp, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:12+0000', 2.2, 'bbb');
    """,
    """
      INSERT INTO :keyspace.com_example_testobject_v1 (device_id, path, reception_timestamp, v_value, v_string) VALUES
        (7f454c46-0201-0100-0000-000000000000, '/', '2017-09-30 07:13+0000', 3.3, 'ccc');
    """,
    """
      INSERT INTO :keyspace.individual_properties (device_id, interface_id, endpoint_id, path, reception_timestamp) VALUES
        (7f454c46-0201-0100-0000-000000000000, db576345-80b1-5358-f305-d77ec39b3d84, 7d03ec11-a59f-47fa-c8f0-0bc9b022649f, '/', '2017-09-30 07:12+0000');
    """
  ]

  def setup_realm(realm_name \\ @test_realm) do
    setup_realm_keyspace(realm_name)
    astarte_keyspace = Realm.astarte_keyspace_name()

    %Realm{realm_name: realm_name}
    |> Repo.insert!(prefix: astarte_keyspace, timeout: 60_000)

    :ok
  end

  def setup_realm_keyspace(realm_name \\ @test_realm) do
    keyspace = Realm.keyspace_name(realm_name)

    execute_query(@create_keyspace, keyspace)
    Database.migrate_realm(realm_name)

    # add datastream interfaces
    execute_query(@create_individual_datastreams_table, keyspace)
    execute_query(@create_test_object_table, keyspace)
  end

  def setup_astarte_keyspace do
    keyspace = Realm.astarte_keyspace_name()

    execute_query(@create_keyspace, keyspace)
    Database.migrate_astarte()
  end

  def create_realm_keyspace(realm_name \\ @test_realm) do
    execute_query(@create_keyspace, Realm.keyspace_name(realm_name))
  end

  def create_astarte_keyspace do
    execute_query(@create_keyspace, Realm.astarte_keyspace_name())
  end

  @doc """
  Creates a realm as it was created by Astarte Housekeeping on old versions of Astarte
  """
  def create_housekeeping_realm(realm_name \\ @test_realm, public_key_pem \\ "") do
    keyspace = Realm.keyspace_name(realm_name)
    latest_schema_version = 21

    execute_query(@create_keyspace, keyspace)
    execute_query(@create_kv_store, keyspace)
    execute_query(@create_names_table, keyspace)
    execute_query(@create_capabilities_type, keyspace)
    execute_query(@create_session_key_type, keyspace)
    execute_query(@create_devices_table, keyspace)
    execute_query(@create_endpoints_table, keyspace)
    execute_query(@create_interfaces_table, keyspace)
    execute_query(@create_individual_properties_table, keyspace)
    execute_query(@create_simple_triggers_table, keyspace)
    execute_query(@create_grouped_devices_table, keyspace)
    execute_query(@create_deletion_in_progress_table, keyspace)
    execute_query(@create_ownership_vouchers_table, keyspace)
    execute_query(@create_to2_sessions_table, keyspace)

    %{
      group: "auth",
      key: "jwt_public_key_pem",
      value: public_key_pem,
      value_type: :string
    }
    |> KvStore.insert(prefix: keyspace)

    %{
      group: "astarte",
      key: "schema_version",
      value: latest_schema_version,
      value_type: :big_integer
    }
    |> KvStore.insert(prefix: keyspace)

    :ok
  end

  @doc """
  Creates a realm as it was created by Astarte Housekeeping on Astarte v1.1.0
  """
  def create_housekeeping_1_1_0_realm(realm_name \\ @test_realm, public_key_pem \\ "") do
    keyspace = Realm.keyspace_name(realm_name)
    schema_1_1_0 = 4

    execute_query(@create_keyspace, keyspace)
    execute_query(@create_kv_store, keyspace)
    execute_query(@create_names_table, keyspace)
    execute_query(@create_devices_1_1_0_table, keyspace)
    execute_query(@create_endpoints_1_1_0_table, keyspace)
    execute_query(@create_interfaces_table, keyspace)
    execute_query(@create_individual_properties_1_1_0_table, keyspace)
    execute_query(@create_simple_triggers_table, keyspace)
    execute_query(@create_grouped_devices_table, keyspace)

    %{
      group: "auth",
      key: "jwt_public_key_pem",
      value: public_key_pem,
      value_type: :string
    }
    |> KvStore.insert(prefix: keyspace)

    %{group: "astarte", key: "schema_version", value: schema_1_1_0, value_type: :big_integer}
    |> KvStore.insert(prefix: keyspace)

    :ok
  end

  @doc """
  Creates the astarte keyspace as it was created by Astarte Housekeeping on old versions of Astarte
  """
  def create_housekeeping_astarte do
    keyspace = Realm.astarte_keyspace_name()
    latest_schema_version = 3
    replication = %{strategy: :simple, factor: 1} |> :erlang.term_to_binary()

    execute_query(@create_keyspace, keyspace)
    execute_query(@create_realms_table, keyspace)
    execute_query(@create_kv_store, keyspace)

    %{
      group: "astarte",
      key: "schema_version",
      value: latest_schema_version,
      value_type: :big_integer
    }
    |> KvStore.insert(prefix: keyspace)

    %{
      group: "astarte",
      key: "db_default_replication",
      value: replication
    }
    |> KvStore.insert(prefix: keyspace)

    :ok
  end

  @doc """
  Creates the astarte keyspace as it was created by Astarte Housekeeping on old versions of Astarte
  """
  def create_housekeeping_1_1_0_astarte do
    keyspace = Realm.astarte_keyspace_name()
    schema_1_1_0 = 2

    execute_query(@create_keyspace, keyspace)
    execute_query(@create_realms_1_1_0_table, keyspace)
    execute_query(@create_kv_store, keyspace)

    %{group: "astarte", key: "schema_version", value: schema_1_1_0, value_type: :big_integer}
    |> KvStore.insert(prefix: keyspace)

    :ok
  end

  def teardown_astarte_keyspace do
    Realm.astarte_keyspace_name()
    |> teardown_keyspace()
  end

  def teardown_realm_keyspace

  def create_keyspace(keyspace_name), do: execute_query(@create_keyspace, keyspace_name)

  def truncate(keyspace_name, table) do
    execute_query("TRUNCATE :keyspace.#{table}", keyspace_name)
  end

  def execute_query(query, keyspace, params \\ [], opts \\ []) do
    String.replace(query, ":keyspace", keyspace)
    |> Repo.query!(params, opts)

    :ok
  end

  def seed_database(realm_name \\ "autotestrealm") do
    keyspace = Realm.keyspace_name(realm_name)

    ["interfaces", "endpoints", "individual_properties", "individual_datastreams", "kv_store"]
    |> Enum.each(&truncate(keyspace, &1))

    devices_list = [
      {"f0VMRgIBAQAAAAAAAAAAAA", 4_500_000, %{"display_name" => "device_a"}},
      {"olFkumNuZ_J0f_d6-8XCDg", 10, nil},
      {"4UQbIokuRufdtbVZt9AsLg", 22, %{"display_name" => "device_b", "serial" => "1234"}},
      {"aWag-VlVKC--1S-vfzZ9uQ", 0, %{"display_name" => "device_c"}},
      {"DKxaeZ9LzUZLz7WPTTAEAA", 300, %{"display_name" => "device_d"}}
    ]

    for {encoded_device_id, total_received_bytes, aliases} <- devices_list do
      {:ok, device_id} = DeviceCore.decode_device_id(encoded_device_id)

      %Device{
        device_id: device_id,
        aliases: aliases,
        total_received_bytes: total_received_bytes,
        connected: false,
        last_connection: ~U[2017-09-28 04:05:00Z],
        last_disconnection: ~U[2017-09-30 04:05:09Z],
        first_registration: ~U[2016-08-15 11:05:01Z],
        first_credentials_request: ~U[2016-08-20 11:05:01Z],
        last_seen_ip: {198, 51, 100, 81},
        last_credentials_request_ip: {198, 51, 100, 89},
        total_received_msgs: 45_000,
        introspection: %{
          "com.test.LCDMonitor" => 1,
          "com.test.SimpleStreamTest" => 1,
          "com.example.TestObject " => 1,
          "com.example.PixelsConfiguration" => 1
        },
        introspection_minor: %{
          "com.test.LCDMonitor" => 3,
          "com.test.SimpleStreamTest" => 0,
          "com.example.TestObject " => 5,
          "com.example.PixelsConfiguration" => 0
        }
      }
      |> Repo.insert!(prefix: keyspace)

      for {_key, device_alias} <- aliases || %{} do
        %Name{object_name: device_alias, object_type: 1, object_uuid: device_id}
        |> Repo.insert(prefix: keyspace)
      end
    end

    # Interfaces

    automaton_accepting_states =
      Base.decode64!(
        "g3QAAAAFYQJtAAAAEHUBDhsZnu783TXSVLDiCSRhBW0AAAAQOQfUHVvKMp2eUUzqKlSpmmEGbQAAABB6pEwRInNH2eYkSuAp3t6qYQdtAAAAEO/5V88D397tl4SocI49jLlhCG0AAAAQNGyA5MqZYnSB9nscG+WVIQ=="
      )

    automaton_transitions =
      Base.decode64!(
        "g3QAAAAIaAJhAG0AAAAAYQFoAmEAbQAAAANmb29hA2gCYQFtAAAABXZhbHVlYQJoAmEDbQAAAABhBGgCYQRtAAAACWJsb2JWYWx1ZWEGaAJhBG0AAAAJbG9uZ1ZhbHVlYQdoAmEEbQAAAAtzdHJpbmdWYWx1ZWEFaAJhBG0AAAAOdGltZXN0YW1wVmFsdWVhCA=="
      )

    %Interface{
      name: "com.test.LCDMonitor",
      major_version: 1,
      minor_version: 3,
      interface_id: "798b93a5-842e-bbad-2e4d-d20306838051",
      automaton_accepting_states: automaton_accepting_states,
      automaton_transitions: automaton_transitions,
      aggregation: :individual,
      ownership: :device,
      storage: "individual_properties",
      storage_type: :multi_interface_individual_properties_dbtable,
      type: :properties
    }
    |> Repo.insert!(prefix: keyspace)

    automaton_accepting_states =
      Base.decode64!(
        "g3QAAAAFYQJtAAAAEHUBDhsZnu783TXSVLDiCSRhBW0AAAAQOQfUHVvKMp2eUUzqKlSpmmEGbQAAABB6pEwRInNH2eYkSuAp3t6qYQdtAAAAEO/5V88D397tl4SocI49jLlhCG0AAAAQNGyA5MqZYnSB9nscG+WVIQ=="
      )

    automaton_transitions =
      Base.decode64!(
        "g3QAAAAIaAJhAG0AAAAAYQFoAmEAbQAAAANmb29hA2gCYQFtAAAABXZhbHVlYQJoAmEDbQAAAABhBGgCYQRtAAAACWJsb2JWYWx1ZWEGaAJhBG0AAAAJbG9uZ1ZhbHVlYQdoAmEEbQAAAAtzdHJpbmdWYWx1ZWEFaAJhBG0AAAAOdGltZXN0YW1wVmFsdWVhCA=="
      )

    %Interface{
      name: "com.test.SimpleStreamTest",
      major_version: 1,
      minor_version: 0,
      interface_id: "0a0da77d-85b5-93d9-d4d2-bd26dd18c9af",
      automaton_accepting_states: automaton_accepting_states,
      automaton_transitions: automaton_transitions,
      aggregation: :individual,
      ownership: :device,
      storage: "individual_datastreams",
      storage_type: :multi_interface_individual_datastream_dbtable,
      type: :datastream
    }
    |> Repo.insert!(prefix: keyspace)

    %Interface{
      name: "com.example.TestObject",
      major_version: 1,
      minor_version: 5,
      interface_id: "db576345-80b1-5358-f305-d77ec39b3d84",
      automaton_accepting_states: nil,
      automaton_transitions: nil,
      aggregation: :object,
      ownership: :device,
      storage: "com_example_testobject_v1",
      storage_type: :one_object_datastream_dbtable,
      type: :datastream
    }
    |> Repo.insert!(prefix: keyspace)

    automaton_accepting_states = Base.decode64!("g3QAAAABYQNtAAAAEOPZVKNVUNqw17mW3O0hiYc=")

    automaton_transitions =
      Base.decode64!("g3QAAAADaAJhAG0AAAAAYQFoAmEBbQAAAABhAmgCYQJtAAAABWNvbG9yYQM=")

    %Interface{
      name: "com.example.PixelsConfiguration",
      major_version: 1,
      minor_version: 0,
      interface_id: "9651f167-a619-3ff5-1c4e-6771fb1929d4",
      automaton_accepting_states: automaton_accepting_states,
      automaton_transitions: automaton_transitions,
      aggregation: :individual,
      ownership: :server,
      storage: "individual_properties",
      storage_type: :multi_interface_individual_properties_dbtable,
      type: :properties
    }
    |> Repo.insert!(prefix: keyspace)

    automaton_accepting_states = Base.decode64!("g3QAAAABYQNtAAAAEGZjaujopxRZWiHuQLZfzfQ=")

    automaton_transitions =
      Base.decode64!(
        "g3QAAAADaAJhAG0AAAADbmV3YQFoAmEBbQAAAAlpbnRlcmZhY2VhAmgCYQJtAAAABXZhbHVlYQM="
      )

    %Interface{
      name: "org.astarte-platform.NewInterface",
      major_version: 0,
      minor_version: 1,
      interface_id: "53d09b30-67cd-dcf3-de1e-2870ead21f13",
      automaton_accepting_states: automaton_accepting_states,
      automaton_transitions: automaton_transitions,
      aggregation: :individual,
      ownership: :device,
      storage: "individual_properties",
      storage_type: :multi_interface_individual_properties_dbtable,
      type: :properties
    }
    |> Repo.insert!(prefix: keyspace)

    # Endpoints

    endpoints = [
      %Endpoint{
        interface_id: "798b93a5-842e-bbad-2e4d-d20306838051",
        endpoint_id: "e6f73631-effc-1d7e-ad52-d3f3a3bae50b",
        allow_unset: false,
        endpoint: "/time/from",
        expiry: 0,
        interface_major_version: 0,
        interface_minor_version: 3,
        interface_name: "com.test.LCDMonitor",
        interface_type: :properties,
        reliability: :unreliable,
        retention: :discard,
        value_type: :longinteger
      },
      %Endpoint{
        interface_id: "798b93a5-842e-bbad-2e4d-d20306838051",
        endpoint_id: "2b2c63dd-bbd9-5735-6d4a-8e56f504edda",
        allow_unset: false,
        endpoint: "/time/to",
        expiry: 0,
        interface_major_version: 0,
        interface_minor_version: 3,
        interface_name: "com.test.LCDMonitor",
        interface_type: :properties,
        reliability: :unreliable,
        retention: :discard,
        value_type: :longinteger
      },
      %Endpoint{
        interface_id: "798b93a5-842e-bbad-2e4d-d20306838051",
        endpoint_id: "801e1035-5fdf-7069-8e6e-3fd2792699ab",
        allow_unset: false,
        endpoint: "/weekSchedule/%{day}/start",
        expiry: 0,
        interface_major_version: 0,
        interface_minor_version: 3,
        interface_name: "com.test.LCDMonitor",
        interface_type: :properties,
        reliability: :unreliable,
        retention: :discard,
        value_type: :longinteger
      },
      %Endpoint{
        interface_id: "798b93a5-842e-bbad-2e4d-d20306838051",
        endpoint_id: "4fe5034a-3d9b-99ec-7ec3-b23716303d33",
        allow_unset: false,
        endpoint: "/lcdCommand",
        expiry: 0,
        interface_major_version: 0,
        interface_minor_version: 3,
        interface_name: "com.test.LCDMonitor",
        interface_type: :properties,
        reliability: :unreliable,
        retention: :discard,
        value_type: :string
      },
      %Endpoint{
        interface_id: "798b93a5-842e-bbad-2e4d-d20306838051",
        endpoint_id: "8ebb62b3-60c1-4ba2-4172-9ddedd809c9f",
        allow_unset: false,
        endpoint: "/weekSchedule/%{day}/stop",
        expiry: 0,
        interface_major_version: 0,
        interface_minor_version: 3,
        interface_name: "com.test.LCDMonitor",
        interface_type: :properties,
        reliability: :unreliable,
        retention: :discard,
        value_type: :longinteger
      },
      %Endpoint{
        interface_id: "0a0da77d-85b5-93d9-d4d2-bd26dd18c9af",
        endpoint_id: "75010e1b-199e-eefc-dd35-d254b0e20924",
        allow_unset: false,
        endpoint: "/%{itemIndex}/value",
        expiry: 0,
        interface_major_version: 1,
        interface_minor_version: 0,
        interface_name: "com.test.SimpleStreamTest",
        interface_type: :datastream,
        reliability: :unique,
        retention: :discard,
        database_retention_policy: :use_ttl,
        database_retention_ttl: 120,
        value_type: :integer
      },
      %Endpoint{
        interface_id: "0a0da77d-85b5-93d9-d4d2-bd26dd18c9af",
        endpoint_id: "3907d41d-5bca-329d-9e51-4cea2a54a99a",
        allow_unset: false,
        endpoint: "/foo/%{param}/stringValue",
        expiry: 0,
        interface_major_version: 1,
        interface_minor_version: 0,
        interface_name: "com.test.SimpleStreamTest",
        interface_type: :datastream,
        reliability: :unique,
        retention: :discard,
        value_type: :string
      },
      %Endpoint{
        interface_id: "0a0da77d-85b5-93d9-d4d2-bd26dd18c9af",
        endpoint_id: "7aa44c11-2273-47d9-e624-4ae029dedeaa",
        allow_unset: false,
        endpoint: "/foo/%{param}/blobValue",
        expiry: 0,
        interface_major_version: 1,
        interface_minor_version: 0,
        interface_name: "com.test.SimpleStreamTest",
        interface_type: :datastream,
        reliability: :unique,
        retention: :discard,
        value_type: :binaryblob
      },
      %Endpoint{
        interface_id: "0a0da77d-85b5-93d9-d4d2-bd26dd18c9af",
        endpoint_id: "eff957cf-03df-deed-9784-a8708e3d8cb9",
        allow_unset: false,
        endpoint: "/foo/%{param}/longValue",
        expiry: 0,
        interface_major_version: 1,
        interface_minor_version: 0,
        interface_name: "com.test.SimpleStreamTest",
        interface_type: :datastream,
        reliability: :unique,
        retention: :discard,
        database_retention_policy: :no_ttl,
        value_type: :longinteger
      },
      %Endpoint{
        interface_id: "0a0da77d-85b5-93d9-d4d2-bd26dd18c9af",
        endpoint_id: "346c80e4-ca99-6274-81f6-7b1c1be59521",
        allow_unset: false,
        endpoint: "/foo/%{param}/timestampValue",
        expiry: 0,
        interface_major_version: 1,
        interface_minor_version: 0,
        interface_name: "com.test.SimpleStreamTest",
        interface_type: :datastream,
        reliability: :unique,
        retention: :discard,
        value_type: :datetime
      },
      %Endpoint{
        interface_id: "0a0da77d-85b5-93d9-d4d2-bd26dd18c9af",
        endpoint_id: "3b39fd3a-f496-26ff-81f6-4c2dd150b864",
        allow_unset: false,
        endpoint: "/encrypted/value",
        expiry: 0,
        interface_major_version: 1,
        interface_minor_version: 0,
        interface_name: "com.test.SimpleStreamTest",
        interface_type: :datastream,
        reliability: :unique,
        retention: :discard,
        value_type: :datetime,
        encrypted: true
      },
      %Endpoint{
        interface_id: "db576345-80b1-5358-f305-d77ec39b3d84",
        endpoint_id: "7c9f14e8-4f2f-977f-c126-d5e1bb9876e7",
        allow_unset: false,
        endpoint: "/string",
        expiry: 0,
        interface_major_version: 1,
        interface_minor_version: 5,
        interface_name: "com.example.TestObject",
        interface_type: :datastream,
        reliability: :guaranteed,
        retention: :stored,
        value_type: :string
      },
      %Endpoint{
        interface_id: "db576345-80b1-5358-f305-d77ec39b3d84",
        endpoint_id: "3b39fd3a-e261-26ff-e523-4c2dd150b864",
        allow_unset: false,
        endpoint: "/value",
        expiry: 0,
        interface_major_version: 1,
        interface_minor_version: 5,
        interface_name: "com.example.TestObject",
        interface_type: :datastream,
        reliability: :guaranteed,
        retention: :stored,
        value_type: :double
      },
      %Endpoint{
        interface_id: "9651f167-a619-3ff5-1c4e-6771fb1929d4",
        endpoint_id: "342c0830-f496-0db0-6776-2d1a7e534022",
        allow_unset: true,
        endpoint: "/%{x}/%{y}/color",
        expiry: 0,
        interface_major_version: 1,
        interface_minor_version: 0,
        interface_name: "com.example.PixelsConfiguration",
        interface_type: :properties,
        reliability: :unreliable,
        retention: :discard,
        value_type: :string
      },
      %Endpoint{
        interface_id: "53d09b30-67cd-dcf3-de1e-2870ead21f13",
        endpoint_id: "66636ae8-e8a7-1459-5a21-ee40b65fcdf4",
        allow_unset: false,
        endpoint: "/new/interface/value",
        expiry: 0,
        interface_major_version: 0,
        interface_minor_version: 1,
        interface_name: "org.astarte-platform.NewInterface",
        interface_type: :properties,
        reliability: :unreliable,
        retention: :discard,
        value_type: :double,
        doc: "The doc.",
        description: "The description.",
        explicit_timestamp: false
      }
    ]

    for endpoint <- endpoints, do: Repo.insert!(endpoint, prefix: keyspace)

    Enum.each(@insert_values, fn query ->
      execute_query(query, keyspace)
    end)

    :ok
  end

  def teardown_realm_keyspace(realm_name \\ "autotestrealm") do
    Realm.keyspace_name(realm_name)
    |> teardown_keyspace()
  end

  defp teardown_keyspace(keyspace) do
    execute_query("DROP KEYSPACE IF EXISTS :keyspace;", keyspace)
    :ok
  end

  def setup_database_access(astarte_instance_id) do
    Astarte.DataAccess.Config
    |> Mimic.stub(:astarte_instance_id, fn -> {:ok, astarte_instance_id} end)
    |> Mimic.stub(:astarte_instance_id!, fn -> astarte_instance_id end)
  end
end
