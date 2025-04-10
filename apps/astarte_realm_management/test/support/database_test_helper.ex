#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.DatabaseTestHelper do
  import Ecto.Query

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.Realms.IndividualDatastream
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.RealmManagement.Config
  alias Astarte.RealmManagement.DatabaseFixtures
  alias Astarte.RealmManagement.Repo
  require Logger

  @jwt_public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE7u5hHn9oE9uy5JoUjwNU6rSEgRlAFh5e
  u9/f1dNImWDuIPeLu8nEiuHlCMy02+YDu0wN2U1psPC7w6AFjv4uTg==
  -----END PUBLIC KEY-----
  """
  @test_realm "autotestrealm"
  defp create_autotestrealm do
    """
    CREATE KEYSPACE #{Realm.keyspace_name(@test_realm)}
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
    """
  end

  defp create_astarte_keyspace do
    """
    CREATE KEYSPACE #{Realm.astarte_keyspace_name()}
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
    """
  end

  defp create_astarte_realms_table do
    """
    CREATE TABLE #{Realm.astarte_keyspace_name()}.realms (
      realm_name ascii,
      device_registration_limit int,
      PRIMARY KEY (realm_name)
    );
    """
  end

  defp insert_autotestrealm_into_realms do
    """
    INSERT INTO #{Realm.astarte_keyspace_name()}.realms (realm_name)
    VALUES ('#{Realm.keyspace_name(@test_realm)}');
    """
  end

  defp create_interfaces_table do
    """
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
  end

  defp create_endpoints_table do
    """
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
  end

  defp create_individual_properties_table do
    """
    CREATE TABLE #{Realm.keyspace_name(@test_realm)}.individual_properties (
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
    )
    """
  end

  defp create_kv_store_table do
    """
    CREATE TABLE #{Realm.keyspace_name(@test_realm)}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
    """
  end

  defp create_simple_triggers_table do
    """
    CREATE TABLE #{Realm.keyspace_name(@test_realm)}.simple_triggers (
      object_id uuid,
      object_type int,
      parent_trigger_id uuid,
      simple_trigger_id uuid,
      trigger_data blob,
      trigger_target blob,

      PRIMARY KEY ((object_id, object_type), parent_trigger_id, simple_trigger_id)
    );
    """
  end

  defp insert_public_key do
    """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.kv_store (group, key, value)
    VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:pem));
    """
  end

  defp create_individual_datastreams_table do
    """
    CREATE TABLE IF NOT EXISTS #{Realm.keyspace_name(@test_realm)}.individual_datastreams (
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
    )
    """
  end

  defp create_names_table do
    """
    CREATE TABLE IF NOT EXISTS #{Realm.keyspace_name(@test_realm)}.names (
        object_name varchar,
        object_uuid uuid,
        PRIMARY KEY ((object_name))
      )
    """
  end

  defp create_grouped_devices_table do
    """
    CREATE TABLE IF NOT EXISTS #{Realm.keyspace_name(@test_realm)}.grouped_devices (
        group_name varchar,
        insertion_uuid timeuuid,
        device_id uuid,
        PRIMARY KEY ((group_name), insertion_uuid, device_id)
      )
    """
  end

  defp create_deleted_devices_table do
    """
    CREATE TABLE IF NOT EXISTS #{Realm.keyspace_name(@test_realm)}.deletion_in_progress (
        device_id uuid,
        vmq_ack boolean,
        dup_start_ack boolean,
        dup_end_ack boolean,
        PRIMARY KEY ((device_id))
      )
    """
  end

  defp create_devices_table do
    """
    CREATE TABLE IF NOT EXISTS #{Realm.keyspace_name(@test_realm)}.devices (
        device_id uuid,
        introspection map<ascii, int>,
        PRIMARY KEY ((device_id))
      )
    """
  end

  def seed_datastream_test_data(device_id, interface_name, major, endpoint_id, path) do
    keyspace_name =
      Realm.keyspace_name(@test_realm)

    interface_id = CQLUtils.interface_id(interface_name, major)

    %IndividualProperty{}
    |> Ecto.Changeset.change(%{
      device_id: device_id,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      path: path
    })
    |> Ecto.Changeset.validate_required([:device_id, :interface_id, :endpoint_id, :path])
    |> Repo.insert!(prefix: keyspace_name)

    %IndividualDatastream{}
    |> Ecto.Changeset.change(%{
      device_id: device_id,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      path: "/0/integerValues",
      value_timestamp: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      reception_timestamp: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      reception_timestamp_submillis: 0,
      integer_value: 42
    })
    |> Ecto.Changeset.validate_required([
      :device_id,
      :interface_id,
      :endpoint_id,
      :path,
      :value_timestamp,
      :reception_timestamp,
      :integer_value
    ])
    |> Repo.insert!(prefix: keyspace_name)

    kv_insert_value =
      %{
        group: "devices-with-data-on-interface-#{interface_name}-v0",
        key: Device.encode_device_id(device_id),
        value: "some_default_value"
      }

    KvStore.insert(kv_insert_value, prefix: keyspace_name, consistency: :all)

    :ok
  end

  def count_rows_for_datastream(device_id, interface_name, major, endpoint_id, path) do
    keyspace_name = Realm.keyspace_name(@test_realm)
    interface_id = CQLUtils.interface_id(interface_name, major)

    query =
      from k in IndividualDatastream,
        prefix: ^keyspace_name,
        where:
          k.device_id == ^device_id and k.interface_id == ^interface_id and
            k.endpoint_id == ^endpoint_id and k.path == ^path,
        select: count()

    Repo.one(query, consistency: Consistency.domain_model(:read))
  end

  def seed_properties_test_value(device_id, interface_name, major, endpoint_id, path) do
    keyspace_name = Realm.keyspace_name(@test_realm)
    interface_id = CQLUtils.interface_id(interface_name, major)

    %IndividualProperty{}
    |> Ecto.Changeset.change(%{
      device_id: device_id,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      path: path
    })
    |> Ecto.Changeset.validate_required([:device_id, :interface_id, :endpoint_id, :path])
    |> Repo.insert!(prefix: keyspace_name)

    kv_insert_value =
      %{
        group: "devices-with-data-on-interface-#{interface_name}-v0",
        key: Device.encode_device_id(device_id),
        value: "some_value"
      }

    KvStore.insert(kv_insert_value, prefix: keyspace_name)

    :ok
  end

  def count_interface_properties_for_device(device_id, interface_name, major) do
    interface_id = CQLUtils.interface_id(interface_name, major)

    keyspace_name =
      Realm.keyspace_name(@test_realm)

    query =
      from i in IndividualProperty,
        prefix: ^keyspace_name,
        where: i.device_id == ^device_id and i.interface_id == ^interface_id,
        select: count()

    Repo.one(query, consistency: Consistency.domain_model(:read))
  end

  def create_test_keyspace() do
    Repo.query!(create_autotestrealm())
    Repo.query!(create_astarte_keyspace())
    Repo.query!(create_astarte_realms_table())
    Repo.query!(insert_autotestrealm_into_realms())
    Repo.query!(create_interfaces_table())
    Repo.query!(create_endpoints_table())
    Repo.query!(create_individual_properties_table())
    Repo.query!(create_kv_store_table())
    Repo.query!(create_simple_triggers_table())
    Repo.query!(create_individual_datastreams_table())
    Repo.query!(create_names_table())
    Repo.query!(create_grouped_devices_table())
    Repo.query!(create_deleted_devices_table())
    Repo.query!(create_devices_table())

    :ok
  end

  def seed_test_data() do
    Enum.each(["interfaces", "endpoints", "individual_properties", "kv_store"], fn table ->
      Repo.query!("TRUNCATE #{Realm.keyspace_name(@test_realm)}.#{table}")
    end)

    with {:ok, _result} <- Repo.query(insert_public_key(), %{pem: @jwt_public_key_pem}) do
      :ok
    else
      error ->
        Logger.warning("Database error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  def drop_test_keyspace do
    query1 = "DROP KEYSPACE #{Realm.keyspace_name(@test_realm)}"
    query2 = "DROP KEYSPACE #{Realm.astarte_keyspace_name()}"

    with {:ok, _} <- Repo.query(query1),
         {:ok, _} <- Repo.query(query2) do
      :ok
    else
      error ->
        Logger.warning("Database error: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  def jwt_public_key_pem_fixture do
    @jwt_public_key_pem
  end

  def seed_individual_datastream_test_data!(opts) do
    %{
      realm_name: realm_name,
      interface_name: interface_name,
      device_id: device_id
    } =
      params =
      DatabaseFixtures.compute_interface_fixtures(
        opts,
        DatabaseFixtures.datastream_values()
      )

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    Xandra.Cluster.run(:xandra, fn conn ->
      statement = """
      INSERT INTO  #{keyspace_name}.individual_datastreams
        (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, integer_value)
      VALUES (:device_id, :interface_id, :endpoint_id, :path, :value_timestamp, :reception_timestamp, :reception_timestamp_submillis, :value);
      """

      prepared = Xandra.prepare!(conn, statement)
      Xandra.execute!(conn, prepared, params)

      kv_store_statement =
        "INSERT INTO #{keyspace_name}.kv_store (group, key) VALUES (:group, :key)"

      kv_store_params = %{
        group: "devices-with-data-on-interface-#{interface_name}-v0",
        key: Device.encode_device_id(device_id),
        value: "some_value"
      }

      kv_store_prepared = Xandra.prepare!(conn, kv_store_statement)
      Xandra.execute!(conn, kv_store_prepared, kv_store_params)
    end)

    :ok
  end

  def seed_individual_properties_test_data!(opts) do
    %{
      realm_name: realm_name
    } =
      params =
      DatabaseFixtures.compute_interface_fixtures(opts, DatabaseFixtures.properties_values())

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    Xandra.Cluster.run(:xandra, fn conn ->
      statement = """
      INSERT INTO #{keyspace_name}.individual_properties
      (device_id, interface_id, endpoint_id, path, reception_timestamp, reception_timestamp_submillis, integer_value)
      VALUES (:device_id, :interface_id, :endpoint_id, :path, :reception_timestamp, :reception_timestamp_submillis, :value)
      """

      prepared = Xandra.prepare!(conn, statement)
      Xandra.execute!(conn, prepared, params)
    end)

    :ok
  end

  def add_interface_to_introspection!(opts) do
    %{realm_name: realm_name} =
      params =
      DatabaseFixtures.compute_introspection_fixtures(
        opts,
        DatabaseFixtures.introspection_values()
      )

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    Xandra.Cluster.run(:xandra, fn conn ->
      statement = """
      INSERT INTO #{keyspace_name}.devices
      (device_id, introspection)
      VALUES (:device_id, :introspection)
      """

      prepared = Xandra.prepare!(conn, statement)
      Xandra.execute!(conn, prepared, params)
    end)

    :ok
  end

  def seed_interfaces_table_object_test_data!(opts) do
    %{realm_name: realm_name} =
      params =
      DatabaseFixtures.compute_interfaces_object_fixtures(
        opts,
        DatabaseFixtures.interfaces_object_values()
      )

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    statement = """
      INSERT INTO #{keyspace_name}.interfaces
      (name, major_version, minor_version, interface_id, storage_type, storage, type, ownership, aggregation, automaton_transitions, automaton_accepting_states, description, doc)
      VALUES (:name, :major_version, :minor_version, :interface_id, :storage_type, :storage, :type, :ownership, :aggregation, :automaton_transitions, :automaton_accepting_states, :description, :doc)
    """

    prepared = Xandra.Cluster.prepare!(:xandra, statement)
    Xandra.Cluster.execute!(:xandra, prepared, params, uuid_format: :binary)
  end

  def create_object_datastream_table!(table_name) do
    Xandra.Cluster.execute(
      :xandra,
      "TRUNCATE TABLE #{CQLUtils.realm_name_to_keyspace_name(@test_realm, Config.astarte_instance_id!())}.#{table_name}"
    )

    Xandra.Cluster.execute!(:xandra, """
        CREATE TABLE IF NOT EXISTS #{CQLUtils.realm_name_to_keyspace_name(@test_realm, Config.astarte_instance_id!())}.#{table_name} (
          device_id uuid,
          path varchar,
          PRIMARY KEY((device_id, path))
        )
    """)
  end

  def seed_object_datastream_test_data!(opts) do
    %{
      interface_name: interface_name,
      interface_major: interface_major,
      realm_name: realm_name
    } =
      params =
      DatabaseFixtures.compute_interface_fixtures(
        opts,
        DatabaseFixtures.datastream_values()
      )

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    interface_table = CQLUtils.interface_name_to_table_name(interface_name, interface_major)

    Xandra.Cluster.run(:xandra, fn conn ->
      statement = """
      INSERT INTO #{keyspace_name}.#{interface_table} (device_id, path)
      VALUES (:device_id, :path);
      """

      prepared = Xandra.prepare!(conn, statement)
      Xandra.execute!(conn, prepared, params)
    end)

    :ok
  end

  def seed_aliases_test_data!(opts) do
    %{realm_name: realm_name} =
      params = DatabaseFixtures.compute_alias_fixtures(opts, DatabaseFixtures.alias_values())

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    Xandra.Cluster.run(:xandra, fn conn ->
      statement = """
      INSERT INTO #{keyspace_name}.names
      (object_name, object_uuid)
      VALUES (:object_name, :object_uuid)
      """

      prepared = Xandra.prepare!(conn, statement)
      Xandra.execute!(conn, prepared, params)
    end)

    :ok
  end

  def seed_groups_test_data!(opts) do
    %{realm_name: realm_name} =
      params = DatabaseFixtures.compute_generic_fixtures(opts, DatabaseFixtures.group_values())

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    Xandra.Cluster.run(:xandra, fn conn ->
      statement = """
      INSERT INTO #{keyspace_name}.grouped_devices
      (group_name, insertion_uuid, device_id)
      VALUES (:group_name, :insertion_uuid, :device_id)
      """

      prepared = Xandra.prepare!(conn, statement)
      Xandra.execute!(conn, prepared, params, uuid_format: :binary, timeuuid_format: :binary)
    end)

    :ok
  end

  def seed_kv_store_test_data!(opts) do
    %{realm_name: realm_name} =
      params = DatabaseFixtures.compute_generic_fixtures(opts, DatabaseFixtures.kv_store_values())

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    Xandra.Cluster.run(:xandra, fn conn ->
      statement = """
      INSERT INTO #{keyspace_name}.kv_store
      (group, key, value)
      VALUES (:group, :key, :value)
      """

      prepared = Xandra.prepare!(conn, statement)
      Xandra.execute!(conn, prepared, params)
    end)

    :ok
  end

  def seed_devices_test_data!(opts) do
    %{realm_name: realm_name} =
      params = DatabaseFixtures.compute_generic_fixtures(opts, DatabaseFixtures.devices_values())

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    Xandra.Cluster.run(:xandra, fn conn ->
      statement = """
      INSERT INTO #{keyspace_name}.devices
      (device_id)
      VALUES (:device_id)
      """

      prepared = Xandra.prepare!(conn, statement)
      Xandra.execute!(conn, prepared, params, uuid_format: :binary)
    end)

    :ok
  end

  def seed_realm_test_data!(opts) do
    params =
      %{realm_name: realm_name} =
      DatabaseFixtures.compute_generic_fixtures(opts, DatabaseFixtures.realm_values())

    Xandra.Cluster.run(:xandra, fn conn ->
      device_registration_limit_statement = """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
      (realm_name, device_registration_limit)
      VALUES (:realm_name, :device_registration_limit)
      """

      device_registration_limit_prepared =
        Xandra.prepare!(conn, device_registration_limit_statement)

      Xandra.execute!(conn, device_registration_limit_prepared, params)

      max_retention_statement = """
      INSERT INTO #{CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())}.kv_store (group, key, value)
      VALUES ('realm_config', 'datastream_maximum_storage_retention', intAsBlob(:datastream_maximum_storage_retention));
      """

      max_retention_prepared = Xandra.prepare!(conn, max_retention_statement)
      Xandra.execute!(conn, max_retention_prepared, params)
    end)

    :ok
  end

  def await_xandra_connected() do
    await_cluster_connected(:xandra)
    await_cluster_connected(:xandra_device_deletion)
  end

  # Taken from https://github.com/lexhide/xandra/blob/main/test/support/test_helper.ex#L5
  defp await_cluster_connected(cluster, tries \\ 10) do
    fun = &Xandra.execute!(&1, "SELECT * FROM system.local")

    case Xandra.Cluster.run(cluster, _options = [], fun) do
      {:error, %Xandra.ConnectionError{} = error} -> raise error
      _other -> :ok
    end
  rescue
    Xandra.ConnectionError ->
      if tries > 0 do
        Process.sleep(100)
        await_cluster_connected(cluster, tries - 1)
      else
        raise("Xandra cluster #{inspect(cluster)} exceeded maximum number of connection attempts")
      end
  end
end
