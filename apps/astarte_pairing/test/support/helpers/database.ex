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
  alias Astarte.DataAccess.Devices.Device, as: DeviceSchema
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

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

  def setup_astarte_keyspace do
    astarte_keyspace = Realm.astarte_keyspace_name()
    execute!(astarte_keyspace, @create_keyspace)
    execute!(astarte_keyspace, @create_kv_store)
    execute!(astarte_keyspace, @create_realms_table)
  end

  def setup!(realm_name) do
    setup_realm_keyspace!(realm_name)
    astarte_keyspace = Realm.astarte_keyspace_name()

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

    :ok
  end

  def teardown_astarte_keyspace do
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

    DeviceSchema
    |> Repo.get(device_id, prefix: keyspace_name)
    |> case do
      nil ->
        {:error, :not_found}

      device ->
        last_connection =
          Keyword.get_lazy(opts, :last_connection, fn -> device.last_connection end)

        last_disconnection =
          Keyword.get_lazy(opts, :last_disconnection, fn -> device.last_disconnection end)

        first_registration =
          Keyword.get_lazy(opts, :first_registration, fn -> device.first_registration end)

        credentials_secret =
          Keyword.get_lazy(opts, :credentials_secret, fn -> device.credentials_secret end)

        first_credentials_request =
          Keyword.get_lazy(opts, :first_credentials_request, fn ->
            device.first_credentials_request
          end)

        last_seen_ip = Keyword.get_lazy(opts, :last_seen_ip, fn -> device.last_seen_ip end)

        last_credentials_request_ip =
          Keyword.get_lazy(opts, :last_credentials_request_ip, fn ->
            device.last_credentials_request_ip
          end)

        total_received_msgs =
          Keyword.get_lazy(opts, :total_received_msgs, fn -> device.total_received_msgs end)

        total_received_bytes =
          Keyword.get_lazy(opts, :total_received_bytes, fn -> device.total_received_bytes end)

        introspection = Keyword.get_lazy(opts, :introspection, fn -> device.introspection end)
        groups = Keyword.get_lazy(opts, :groups, fn -> device.groups end)

        device
        |> Ecto.Changeset.change(%{
          last_connection: last_connection,
          last_disconnection: last_disconnection,
          first_registration: first_registration,
          last_seen_ip: last_seen_ip,
          credentials_secret: credentials_secret,
          first_credentials_request: first_credentials_request,
          last_credentials_request_ip: last_credentials_request_ip,
          total_received_msgs: total_received_msgs,
          total_received_bytes: total_received_bytes,
          introspection: introspection,
          groups: groups
        })
        |> Repo.update(prefix: keyspace_name)
    end
  end

  def remove_device(device_id, realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    %DeviceSchema{device_id: device_id}
    |> Repo.delete(prefix: keyspace)

    :ok
  end

  def insert_deletion_in_progress(device_id, realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    execute!(realm_keyspace, @deletion_in_progress_statement, %{
      "device_id" => device_id
    })
  end

  def insert_public_key!(realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    jwt_public_key_pem = Application.get_env(:astarte_pairing, :jwt_public_key_pem)

    execute!(realm_keyspace, @insert_public_key, %{"pem" => jwt_public_key_pem})
  end

  def insert_datastream_maximum_storage_retention!(realm_name, max_retention) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    execute!(realm_keyspace, @insert_datastream_maximum_storage_retention, %{
      "max_retention" => max_retention
    })
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
end
