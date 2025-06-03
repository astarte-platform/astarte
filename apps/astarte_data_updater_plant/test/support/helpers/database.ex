#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Helpers.Database do
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.Core.CQLUtils
  alias Astarte.DataAccess.Devices.Device, as: DeviceSchema
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  import Ecto.Query

  @create_keyspace """
  CREATE KEYSPACE :keyspace
    WITH
      replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
      durable_writes = true;
  """

  @drop_keyspace """
  DROP KEYSPACE :keyspace
  """

  @create_realms_table """
  CREATE TABLE :keyspace.realms (
    realm_name varchar,
    device_registration_limit int,

    PRIMARY KEY (realm_name)
  );
  """

  @create_kv_store """
  CREATE TABLE :keyspace.kv_store (
    group varchar,
    key varchar,
    value blob,

    PRIMARY KEY ((group), key)
  )
  """

  @create_names_table """
  CREATE TABLE :keyspace.names (
    object_name varchar,
    object_type int,
    object_uuid uuid,

    PRIMARY KEY ((object_name), object_type)
  )
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

    groups map<text, timeuuid>,

    PRIMARY KEY (device_id)
  )
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
    description text,
    doc text,

    PRIMARY KEY (name, major_version)
  )
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
    description text,
    doc text,

    PRIMARY KEY ((interface_id), endpoint_id)
  )
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

  @create_individual_properties_table """
  CREATE TABLE :keyspace.individual_properties (
    device_id uuid,
    interface_id uuid,
    endpoint_id uuid,
    path text,
    reception_timestamp timestamp,
    reception_timestamp_submillis smallint,
    double_value double,
    integer_value int,
    boolean_value boolean,
    longinteger_value bigint,
    string_value text,
    binaryblob_value blob,
    datetime_value timestamp,
    doublearray_value list<double>,
    integerarray_value list<int>,
    booleanarray_value list<boolean>,
    longintegerarray_value list<bigint>,
    stringarray_value list<text>,
    binaryblobarray_value list<blob>,
    datetimearray_value list<timestamp>,

    PRIMARY KEY((device_id, interface_id), endpoint_id, path)
  );
  """

  @create_individual_datastreams_table """
  CREATE TABLE :keyspace.individual_datastreams (
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
      PRIMARY KEY ((device_id, interface_id, endpoint_id, path), value_timestamp, reception_timestamp, reception_timestamp_submillis)
  )
  """

  @create_groups_table """
  CREATE TABLE :keyspace.grouped_devices (
    group_name varchar,
    insertion_uuid timeuuid,
    device_id uuid,
    PRIMARY KEY ((group_name), insertion_uuid, device_id)
  )
  """

  @create_deletion_in_progress_table """
  CREATE TABLE :keyspace.deletion_in_progress (
      device_id uuid,
      vmq_ack boolean,
      dup_start_ack boolean,
      dup_end_ack boolean,
      PRIMARY KEY ((device_id))
    )
  """

  @insert_public_key """
    INSERT INTO :keyspace.kv_store (group, key, value)
    VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:pem));
  """

  @insert_datastream_maximum_storage_retention """
    INSERT INTO :keyspace.kv_store (group, key, value)
    VALUES ('realm_config', 'datastream_maximum_storage_retention', intAsBlob(:max_retention));
  """

  @deletion_in_progress_statement """
    INSERT INTO :keyspace.deletion_in_progress (device_id)
    VALUES (:device_id)
  """

  @jwt_public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE7u5hHn9oE9uy5JoUjwNU6rSEgRlAFh5e
  u9/f1dNImWDuIPeLu8nEiuHlCMy02+YDu0wN2U1psPC7w6AFjv4uTg==
  -----END PUBLIC KEY-----
  """

  @insert_endpoints [
    """
      INSERT INTO :keyspace.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, e6f73631-effc-1d7e-ad52-d3f3a3bae50b, False, '/time/from', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO :keyspace.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 2b2c63dd-bbd9-5735-6d4a-8e56f504edda, False, '/time/to', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO :keyspace.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 801e1035-5fdf-7069-8e6e-3fd2792699ab, False, '/weekSchedule/%{day}/start', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO :keyspace.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 4fe5034a-3d9b-99ec-7ec3-b23716303d33, False, '/lcdCommand', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 7);
    """,
    """
      INSERT INTO :keyspace.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (798b93a5-842e-bbad-2e4d-d20306838051, 8ebb62b3-60c1-4ba2-4172-9ddedd809c9f, False, '/weekSchedule/%{day}/stop', 0, 0, 3, 'com.test.LCDMonitor', 1, 1, 1, 5);
    """,
    """
      INSERT INTO :keyspace.endpoints (interface_id, endpoint_id, allow_unset, endpoint, expiry, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (0a0da77d-85b5-93d9-d4d2-bd26dd18c9af, 75010e1b-199e-eefc-dd35-d254b0e20924, False, '/%{itemIndex}/value', 0, 1, 0, 'com.test.SimpleStreamTest', 2, 3, 1, 3);
    """
  ]

  def setup!(realm_name) do
    setup_realm_keyspace!(realm_name)

    astarte_keyspace = Realm.astarte_keyspace_name()
    execute!(astarte_keyspace, @create_keyspace)
    execute!(astarte_keyspace, @create_kv_store)
    execute!(astarte_keyspace, @create_realms_table)

    %Realm{realm_name: realm_name}
    |> Repo.insert!(prefix: astarte_keyspace)

    :ok
  end

  def setup_realm_keyspace!(realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)
    execute!(realm_keyspace, @create_keyspace)
    execute!(realm_keyspace, @create_devices_table)
    execute!(realm_keyspace, @create_groups_table)
    execute!(realm_keyspace, @create_names_table)
    execute!(realm_keyspace, @create_kv_store)
    execute!(realm_keyspace, @create_endpoints_table)
    execute!(realm_keyspace, @create_simple_triggers_table)
    execute!(realm_keyspace, @create_individual_properties_table)
    execute!(realm_keyspace, @create_individual_datastreams_table)
    execute!(realm_keyspace, @create_interfaces_table)
    execute!(realm_keyspace, @create_deletion_in_progress_table)

    Enum.each(@insert_endpoints, fn query ->
      execute!(realm_keyspace, query)
    end)

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
    |> Repo.insert!(prefix: realm_keyspace)

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
    |> Repo.insert!(prefix: realm_keyspace)

    :ok
  end

  def teardown!(realm_name) do
    teardown_realm_keyspace!(realm_name)
    astarte_keyspace = Realm.astarte_keyspace_name()
    execute!(astarte_keyspace, @drop_keyspace)
    :ok
  end

  def teardown_realm_keyspace!(realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)
    execute!(realm_keyspace, @drop_keyspace)
    :ok
  end

  def insert_device(device_id, realm_name, opts \\ []) do
    keyspace_name = Realm.keyspace_name(realm_name)

    last_connection = Keyword.get(opts, :last_connection)
    last_disconnection = Keyword.get(opts, :last_disconnection)

    first_registration =
      Keyword.get(opts, :first_registration, DateTime.utc_now() |> DateTime.to_unix(:millisecond))

    last_seen_ip = Keyword.get(opts, :last_seen_ip)
    last_credentials_request_ip = Keyword.get(opts, :last_credentials_request_ip)
    total_received_msgs = Keyword.get(opts, :total_received_msgs, 0)
    total_received_bytes = Keyword.get(opts, :total_received_bytes, 0)
    introspection = Keyword.get(opts, :introspection, %{})
    groups = Keyword.get(opts, :groups, [])
    groups_map = for group <- groups, do: {group, UUID.uuid1()}

    %DeviceSchema{}
    |> Ecto.Changeset.change(%{
      device_id: device_id,
      last_connection: last_connection,
      last_disconnection: last_disconnection,
      first_registration: first_registration,
      last_seen_ip: last_seen_ip,
      last_credentials_request_ip: last_credentials_request_ip,
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes,
      introspection: introspection,
      groups: groups_map
    })
    |> Repo.insert(prefix: keyspace_name)
  end

  def update_device(device_id, realm_name, opts \\ []) do
    keyspace_name = Realm.keyspace_name(realm_name)

    last_connection = Keyword.get(opts, :last_connection)
    last_disconnection = Keyword.get(opts, :last_disconnection)

    first_registration =
      Keyword.get(opts, :first_registration, DateTime.utc_now() |> DateTime.to_unix(:millisecond))

    last_seen_ip = Keyword.get(opts, :last_seen_ip)
    last_credentials_request_ip = Keyword.get(opts, :last_credentials_request_ip)
    total_received_msgs = Keyword.get(opts, :total_received_msgs, 0)
    total_received_bytes = Keyword.get(opts, :total_received_bytes, 0)
    introspection = Keyword.get(opts, :introspection, %{})
    groups = Keyword.get(opts, :groups, [])
    groups_map = for group <- groups, do: {group, UUID.uuid1()}

    DeviceSchema
    |> Repo.get(device_id, prefix: keyspace_name)
    |> case do
      nil ->
        {:error, :not_found}

      device ->
        device
        |> Ecto.Changeset.change(%{
          last_connection: last_connection,
          last_disconnection: last_disconnection,
          first_registration: first_registration,
          last_seen_ip: last_seen_ip,
          last_credentials_request_ip: last_credentials_request_ip,
          total_received_msgs: total_received_msgs,
          total_received_bytes: total_received_bytes,
          introspection: introspection,
          groups: groups_map
        })
        |> Repo.update(prefix: keyspace_name)
    end
  end

  def insert_deletion_in_progress(device_id, realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    execute!(realm_keyspace, @deletion_in_progress_statement, %{
      "device_id" => device_id
    })
  end

  def insert_public_key!(realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    execute!(realm_keyspace, @insert_public_key, %{"pem" => @jwt_public_key_pem})
  end

  def insert_datastream_maximum_storage_retention!(realm_name, max_retention) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    execute!(realm_keyspace, @insert_datastream_maximum_storage_retention, %{
      "max_retention" => max_retention
    })
  end

  def make_timestamp(timestamp_string) do
    {:ok, date_time, _} = DateTime.from_iso8601(timestamp_string)
    DateTime.to_unix(date_time, :millisecond) * 10000
  end

  def gen_tracking_id() do
    message_id = :erlang.unique_integer([:monotonic]) |> Integer.to_string()
    delivery_tag = {:injected_msg, make_ref()}
    {message_id, delivery_tag}
  end

  def random_device_id() do
    seq = :crypto.strong_rand_bytes(16)
    <<u0::48, _::4, u1::12, _::2, u2::62>> = seq
    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
  end

  defp execute!(keyspace, query, params \\ [], opts \\ []) do
    String.replace(query, ":keyspace", keyspace)
    |> Repo.query!(params, opts)
  end

  def setup_database_access(astarte_instance_id) do
    Astarte.DataAccess.Config
    |> Mimic.stub(:astarte_instance_id, fn -> {:ok, astarte_instance_id} end)
    |> Mimic.stub(:astarte_instance_id!, fn -> astarte_instance_id end)
  end

  def insert_values(realm_name, device, interface, mapping_update) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    reception_timestamp_submillis = StreamData.integer() |> Enum.at(0)
    keyspace = Realm.keyspace_name(realm_name)
    column_name = CQLUtils.type_to_db_column_name(mapping_update.value_type)
    db_value = mapping_update.value

    endpoint_id = get_endpoint_id(realm_name, interface)

    insert_value = %{
      "device_id" => device.device_id,
      "interface_id" => interface.interface_id,
      "endpoint_id" => endpoint_id,
      "path" => mapping_update.path,
      "reception_timestamp" => timestamp,
      "reception_timestamp_submillis" => reception_timestamp_submillis,
      column_name => db_value
    }

    insert_opts = [
      prefix: keyspace
    ]

    _ = Repo.insert_all("individual_properties", [insert_value], insert_opts)
  end

  defp get_endpoint_id(realm_name, interface) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from e in Endpoint, where: [interface_id: ^interface.interface_id], select: e.endpoint_id

    Repo.one(query, prefix: keyspace)
  end
end
