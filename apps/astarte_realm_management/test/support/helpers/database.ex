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

defmodule Astarte.Test.Helpers.Database do
  alias Astarte.Core.Realm
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.Realm

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

  @jwt_public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE7u5hHn9oE9uy5JoUjwNU6rSEgRlAFh5e
  u9/f1dNImWDuIPeLu8nEiuHlCMy02+YDu0wN2U1psPC7w6AFjv4uTg==
  -----END PUBLIC KEY-----
  """

  def setup!(realm_name) do
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

    astarte_keyspace = Realm.astarte_keyspace_name()
    execute!(astarte_keyspace, @create_keyspace)
    execute!(astarte_keyspace, @create_kv_store)
    execute!(astarte_keyspace, @create_realms_table)

    %Realm{realm_name: realm_name}
    |> Repo.insert!(prefix: astarte_keyspace)

    :ok
  end

  def teardown!(realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)
    astarte_keyspace = Realm.astarte_keyspace_name()

    execute!(realm_keyspace, @drop_keyspace)
    execute!(astarte_keyspace, @drop_keyspace)

    :ok
  end

  def insert_device_registration_limit!(realm, limit) do
    keyspace = Realm.astarte_keyspace_name()

    %Realm{
      realm_name: realm,
      device_registration_limit: limit
    }
    |> Repo.insert!(prefix: keyspace)
  end

  def set_datastream_maximum_storage_retention(realm, value) do
    keyspace = Realm.keyspace_name(realm)

    %{
      group: "realm_config",
      key: "datastream_maximum_storage_retention",
      value: value,
      value_type: :integer
    }
    |> KvStore.insert(prefix: keyspace)
  end

  def insert_public_key!(realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    execute!(realm_keyspace, @insert_public_key, %{pem: @jwt_public_key_pem})
  end

  defp execute!(keyspace, query, params \\ [], opts \\ []) do
    String.replace(query, ":keyspace", keyspace)
    |> Repo.query!(params, opts)
  end
end
