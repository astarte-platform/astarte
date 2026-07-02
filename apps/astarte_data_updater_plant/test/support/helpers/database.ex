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
  @moduledoc """
  This module provides helper functions and setup for tests related to the database in the DataUpdaterPlant.
  """
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Device, as: DeviceAccess
  alias Astarte.DataAccess.Device.InsertContext
  alias Astarte.DataAccess.Devices.Device, as: DeviceSchema
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Realms.Interface, as: InterfaceSchema
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries

  @create_keyspace """
  CREATE KEYSPACE :keyspace
    WITH
      replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
      durable_writes = true;
  """

  @drop_keyspace """
  DROP KEYSPACE IF EXISTS :keyspace
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
      encryptedblob_value blob,
      encrypted_dek blob,

      PRIMARY KEY ((device_id, interface_id, endpoint_id, path), value_timestamp, reception_timestamp, reception_timestamp_submillis)
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

  def setup_astarte_keyspace do
    astarte_keyspace = Realm.astarte_keyspace_name()
    execute!(astarte_keyspace, @create_keyspace, [], timeout: 60_000)
    Database.migrate_astarte()
  end

  def setup!(realm_name) do
    setup_realm_keyspace!(realm_name)
    astarte_keyspace = Realm.astarte_keyspace_name()

    %Realm{realm_name: realm_name}
    |> Repo.insert!(prefix: astarte_keyspace, timeout: 60_000)

    :ok
  end

  def setup_realm_keyspace!(realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)
    execute!(realm_keyspace, @create_keyspace, [], timeout: 60_000)
    Database.migrate_realm(realm_name)
    execute!(realm_keyspace, @create_individual_datastreams_table, [], timeout: 60_000)

    Enum.each(@insert_endpoints, fn query ->
      execute!(realm_keyspace, query, [], timeout: 60_000)
    end)

    %InterfaceSchema{}
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
    |> Repo.insert!(prefix: realm_keyspace, timeout: 60_000)

    %InterfaceSchema{}
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
    |> Repo.insert!(prefix: realm_keyspace, timeout: 60_000)

    :ok
  end

  def teardown_astarte_keyspace do
    astarte_keyspace = Realm.astarte_keyspace_name()
    execute!(astarte_keyspace, @drop_keyspace, [], timeout: 60_000)
    :ok
  end

  def teardown_realm_keyspace!(realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)
    execute!(realm_keyspace, @drop_keyspace, [], timeout: 60_000)
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

  def remove_device(device_id, realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    %DeviceSchema{device_id: device_id}
    |> Repo.delete(prefix: keyspace)

    :ok
  end

  def insert_deletion_in_progress(device_id, realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    execute!(
      realm_keyspace,
      @deletion_in_progress_statement,
      %{
        "device_id" => device_id
      },
      timeout: 60_000
    )
  end

  def insert_public_key!(realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    execute!(realm_keyspace, @insert_public_key, %{"pem" => @jwt_public_key_pem}, timeout: 60_000)
  end

  def insert_datastream_maximum_storage_retention!(realm_name, max_retention) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    execute!(
      realm_keyspace,
      @insert_datastream_maximum_storage_retention,
      %{
        "max_retention" => max_retention
      },
      timeout: 60_000
    )
  end

  def make_timestamp(timestamp_string) do
    {:ok, date_time, _} = DateTime.from_iso8601(timestamp_string)
    DateTime.to_unix(date_time, :millisecond) * 10_000
  end

  def random_device_id do
    seq = :crypto.strong_rand_bytes(16)
    <<u0::48, _::4, u1::12, _::2, u2::62>> = seq
    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
  end

  defp execute!(keyspace, query, params, opts) do
    String.replace(query, ":keyspace", keyspace)
    |> Repo.query!(params, opts)
  end

  def setup_database_access(astarte_instance_id) do
    Astarte.DataAccess.Config
    |> Mimic.stub(:astarte_instance_id, fn -> {:ok, astarte_instance_id} end)
    |> Mimic.stub(:astarte_instance_id!, fn -> astarte_instance_id end)
  end

  def insert_values(realm_name, device, interface, interface_descriptor, mapping_updates) do
    mappings_map = interface.mappings |> Map.new(&{&1.endpoint_id, &1})

    mapping_updates
    |> Enum.scan(initial_timestamp(), fn mapping_update, old_timestamp ->
      timestamp = old_timestamp + random_interval()

      {:ok, mapping} =
        Core.Interface.resolve_path(mapping_update.path, interface_descriptor, mappings_map)

      insert_context = %InsertContext{
        realm: realm_name,
        device_id: device.device_id,
        interface_descriptor: interface_descriptor,
        mapping: mapping,
        path: mapping_update.path,
        value: mapping_update.value,
        value_timestamp: timestamp,
        reception_timestamp: timestamp,
        opts: []
      }

      :ok = DeviceAccess.insert_value_into_db(insert_context)

      timestamp
    end)
  end

  def delete_values(realm_name, device, interface, mapping_updates) do
    mappings_map = interface.mappings |> Map.new(&{&1.endpoint_id, &1})

    {:ok, interface_descriptor} =
      Interface.fetch_interface_descriptor(realm_name, interface.name, interface.major_version)

    Enum.each(mapping_updates, fn mapping_update ->
      {:ok, mapping} =
        Core.Interface.resolve_path(mapping_update.path, interface_descriptor, mappings_map)

      :ok =
        Queries.delete_property_from_db(
          realm_name,
          device.device_id,
          interface_descriptor,
          mapping.endpoint_id,
          mapping_update.path
        )
    end)
  end

  defp initial_timestamp do
    # Start of January 2020 in decimicrosecond
    minimum = 157_783_680_000_000
    # End of December 2025 in decimicrosecond
    maximum = 176_722_559_999_999

    :rand.uniform(maximum - minimum) + minimum
  end

  defp random_interval do
    # 1 second in decimicrosecond
    minimum = 10_000_000
    # 10 seconds in decimicrosecond
    maximum = 100_000_000

    :rand.uniform(maximum - minimum) + minimum
  end
end
