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

defmodule Astarte.RealmManagement.QueriesTest do
  use ExUnit.Case
  import Ecto.Query

  alias Astarte.Core.Interface, as: InterfaceDocument
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.CQLUtils
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.Realms.IndividualDatastream
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.UUID
  alias Astarte.RealmManagement.DatabaseTestHelper
  alias Astarte.RealmManagement.Queries
  alias Astarte.RealmManagement.Repo

  @test_realm "autotestrealm"
  @object_datastream_interface_json """
  {
   "interface_name": "com.ispirata.Hemera.DeviceLog",
   "version_major": 1,
   "version_minor": 0,
   "type": "datastream",
   "quality": "producer",
   "aggregate": true,
   "mappings": [
       {
           "path": "/message",
           "type": "string",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/timestamp",
           "type": "datetime",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/monotonicTimestamp",
           "type": "longinteger",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/applicationId",
           "type": "string",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/pid",
           "type": "integer",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/cmdLine",
           "type": "string",
           "reliability": "guaranteed",
           "retention": "stored"
       }
   ]
  }
  """
  @insert_log_line0_device_a """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.com_ispirata_hemera_devicelog_v1
      (device_id, path, reception_timestamp, reception_timestamp_submillis, v_message, v_timestamp, v_monotonictimestamp, v_applicationid, v_pid, v_cmdline)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, '/', '2010-02-04 04:05+0000', 0, 'test', '2010-02-03 04:05+0000', 9123456789012345678, 'com.test', 5, '/bin/test')
  """

  @insert_log_line1_device_a """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.com_ispirata_hemera_devicelog_v1
      (device_id, path, reception_timestamp, reception_timestamp_submillis, v_message, v_timestamp, v_monotonictimestamp, v_applicationid, v_pid, v_cmdline)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, '/', '2012-02-04 04:06+0000', 0, 'testです', '2012-02-03 04:06+0000', -1, 'this.is.a.bit.longer.string', -2, '/usr/bin/things/test')
  """

  @insert_log_line0_device_b """
    INSERT INTO #{Realm.keyspace_name(@test_realm)}.com_ispirata_hemera_devicelog_v1
      (device_id, path, reception_timestamp, reception_timestamp_submillis, v_message, v_timestamp, v_monotonictimestamp, v_applicationid, v_pid, v_cmdline)
      VALUES (536be249-bbbb-4e02-9583-5a4833cbfe49, '/', '2012-02-03 04:06+0000', 0, 'testです', '2010-02-03 04:06+0000', -1, 'this.is.a.bit.longer.string', -2, '/usr/bin/things/test')
  """

  @count_log_entries_for_device_a """
    SELECT COUNT(*) FROM #{Realm.keyspace_name(@test_realm)}.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND path='/';
  """

  @count_log_entries_for_device_b """
    SELECT COUNT(*) FROM #{Realm.keyspace_name(@test_realm)}.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-bbbb-4e02-9583-5a4833cbfe49 AND path='/';
  """

  @count_log_entries_for_device_c """
    SELECT COUNT(*) FROM #{Realm.keyspace_name(@test_realm)}.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-cccc-4e02-9583-5a4833cbfe49 AND path='/';
  """

  @a_log_entry_for_device_a """
    SELECT * FROM #{Realm.keyspace_name(@test_realm)}.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND path='/' AND reception_timestamp > '2011-02-03 04:05+0000';
  """

  @an_older_log_entry_for_device_a """
    SELECT * FROM #{Realm.keyspace_name(@test_realm)}.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND path='/' AND reception_timestamp <= '2011-02-03 04:05+0000';
  """

  @individual_property_device_owned_interface """
  {
       "interface_name": "com.ispirata.Hemera.DeviceLog.Status",
       "version_major": 2,
       "version_minor": 1,
       "type": "properties",
       "quality": "producer",
       "mappings": [
           {
               "path": "/filterRules/%{ruleId}/%{filterKey}/value",
               "type": "string",
               "allow_unset": true
           }
       ]
  }
  """

  @insert_devicelog_status_0 """
  INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties
    (device_id, interface_id, endpoint_id, path, reception_timestamp, reception_timestamp_submillis, string_value)
    VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/filterRules/0/testKey/value', '2012-02-03 04:06+0000', 0, 'T€ST_VÆLÙE')
  """

  @insert_devicelog_status_1 """
  INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_properties
    (device_id, interface_id, endpoint_id, path, reception_timestamp, reception_timestamp_submillis, string_value)
    VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/filterRules/1/testKey2/value', '2012-02-03 04:06+0000', 0, 'test')
  """

  @individual_datastream_with_explicit_timestamp_interface_json """
  {
   "interface_name": "com.timestamp.Test",
   "version_major": 1,
   "version_minor": 0,
   "type": "datastream",
   "quality": "producer",
   "aggregation": "individual",
   "explicit_timestamp": true,
   "mappings": [
       {
           "path": "/test/%{ind}/v",
           "type": "longinteger",
           "reliability": "guaranteed",
           "retention": "stored"
       }
   ]
  }
  """

  @insert_timestamp_test_value """
  INSERT INTO #{Realm.keyspace_name(@test_realm)}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, longinteger_value)
    VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/test/:ind/v', :value_timestamp, :reception_timestamp, 0, :num) ;
  """

  setup do
    DatabaseTestHelper.seed_test_data()
  end

  setup_all do
    DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      DatabaseTestHelper.drop_test_keyspace()
    end)
  end

  def retrieve_endpoint_id(interface_name, interface_major, path) do
    keyspace_name = Realm.keyspace_name(@test_realm)

    query =
      from i in Interface,
        prefix: ^keyspace_name,
        where: i.name == ^interface_name and i.major_version == ^interface_major

    interface_row =
      case Repo.all(query, consistency: Consistency.domain_model(:read)) do
        [] -> nil
        [interface_row | _] -> interface_row
      end

    automaton =
      {:erlang.binary_to_term(interface_row.automaton_transitions),
       :erlang.binary_to_term(interface_row.automaton_accepting_states)}

    {:ok, endpoint_id} = Astarte.Core.Mapping.EndpointsAutomaton.resolve_path(path, automaton)

    endpoint_id
  end

  def find_endpoint(interface_name, interface_major, endpoint) do
    keyspace_name = Realm.keyspace_name(@test_realm)
    intreface_id = Astarte.Core.CQLUtils.interface_id(interface_name, interface_major)

    query =
      from e in Endpoint,
        prefix: ^keyspace_name,
        where: e.interface_id == ^intreface_id

    Repo.all(query, consistency: Consistency.domain_model(:read))
    |> Enum.to_list()
    |> Enum.find(fn row ->
      row.endpoint == endpoint
    end)
  end

  test "object interface install" do
    json_obj = Jason.decode!(@object_datastream_interface_json)
    interface_changeset = InterfaceDocument.changeset(%InterfaceDocument{}, json_obj)
    {:ok, intdoc} = Ecto.Changeset.apply_action(interface_changeset, :insert)

    %{
      name: interface_name,
      major_version: major_version,
      minor_version: minor_version
    } = InterfaceDescriptor.from_interface(intdoc)

    {:ok, automaton} = Astarte.Core.Mapping.EndpointsAutomaton.build(intdoc.mappings)

    assert Queries.is_interface_major_available?(@test_realm, interface_name, major_version) ==
             {:ok, false}

    assert Queries.is_interface_major_available?(@test_realm, interface_name, major_version - 1) ==
             {:ok, false}

    assert Queries.interface_available_versions(@test_realm, interface_name) ==
             {:error, :interface_not_found}

    assert Queries.get_interfaces_list(@test_realm) == {:ok, []}

    Queries.install_new_interface(@test_realm, intdoc, automaton)

    assert Queries.is_interface_major_available?(@test_realm, interface_name, major_version) ==
             {:ok, true}

    assert Queries.is_interface_major_available?(@test_realm, interface_name, major_version - 1) ==
             {:ok, false}

    assert Queries.interface_available_versions(@test_realm, interface_name) ==
             {:ok,
              [
                [
                  major_version: major_version,
                  minor_version: minor_version
                ]
              ]}

    assert Queries.get_interfaces_list(@test_realm) == {:ok, ["com.ispirata.Hemera.DeviceLog"]}

    Repo.query!(@insert_log_line0_device_a)
    Repo.query!(@insert_log_line1_device_a)
    Repo.query!(@insert_log_line0_device_b)

    %{rows: [[count | _rest]]} =
      Repo.query!(@count_log_entries_for_device_a)

    assert count == 2

    %{rows: [[count | _rest]]} =
      Repo.query!(@count_log_entries_for_device_b)

    assert count == 1

    %{rows: [[count | _rest]]} =
      Repo.query!(@count_log_entries_for_device_c)

    assert count == 0

    column_names = [
      :device_id,
      :path,
      :reception_timestamp,
      :reception_timestamp_submillis,
      :v_applicationid,
      :v_cmdline,
      :v_message,
      :v_monotonictimestamp,
      :v_pid,
      :v_timestamp
    ]

    %{rows: [values]} = Repo.query!(@a_log_entry_for_device_a)

    a_log_entry = Enum.zip(column_names, values) |> Enum.into([])

    assert a_log_entry == [
             device_id: <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>,
             path: "/",
             reception_timestamp: ~U[2012-02-04 04:06:00.000Z],
             reception_timestamp_submillis: 0,
             v_applicationid: "this.is.a.bit.longer.string",
             v_cmdline: "/usr/bin/things/test",
             v_message: "testです",
             v_monotonictimestamp: -1,
             v_pid: -2,
             v_timestamp: ~U[2012-02-03 04:06:00.000Z]
           ]

    %{rows: [values]} = Repo.query!(@an_older_log_entry_for_device_a)

    an_older_log_entry = Enum.zip(column_names, values) |> Enum.into([])

    assert an_older_log_entry == [
             device_id: <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>,
             path: "/",
             reception_timestamp: ~U[2010-02-04 04:05:00.000Z],
             reception_timestamp_submillis: 0,
             v_applicationid: "com.test",
             v_cmdline: "/bin/test",
             v_message: "test",
             v_monotonictimestamp: 9_123_456_789_012_345_678,
             v_pid: 5,
             v_timestamp: ~U[2010-02-03 04:05:00.000Z]
           ]

    Repo.query!("DROP TABLE #{Realm.keyspace_name(@test_realm)}.com_ispirata_hemera_devicelog_v1")
  end

  test "individual interface install" do
    keyspace_name = Realm.keyspace_name(@test_realm)

    json_obj = Jason.decode!(@individual_property_device_owned_interface)
    interface_changeset = InterfaceDocument.changeset(%InterfaceDocument{}, json_obj)
    {:ok, intdoc} = Ecto.Changeset.apply_action(interface_changeset, :insert)

    %{
      name: interface_name,
      major_version: major_version,
      minor_version: minor_version
    } = InterfaceDescriptor.from_interface(intdoc)

    {:ok, automaton} = Astarte.Core.Mapping.EndpointsAutomaton.build(intdoc.mappings)

    assert Queries.is_interface_major_available?(@test_realm, interface_name, major_version) ==
             {:ok, false}

    assert Queries.is_interface_major_available?(@test_realm, interface_name, major_version - 1) ==
             {:ok, false}

    assert Queries.interface_available_versions(@test_realm, interface_name) ==
             {:error, :interface_not_found}

    assert Queries.get_interfaces_list(@test_realm) == {:ok, []}

    Queries.install_new_interface(@test_realm, intdoc, automaton)

    assert Queries.is_interface_major_available?(@test_realm, interface_name, major_version) ==
             {:ok, true}

    assert Queries.is_interface_major_available?(@test_realm, interface_name, major_version - 1) ==
             {:ok, false}

    assert Queries.interface_available_versions(@test_realm, interface_name) ==
             {:ok,
              [
                [
                  major_version: major_version,
                  minor_version: minor_version
                ]
              ]}

    assert Queries.get_interfaces_list(@test_realm) ==
             {:ok, ["com.ispirata.Hemera.DeviceLog.Status"]}

    endpoint =
      find_endpoint(
        "com.ispirata.Hemera.DeviceLog.Status",
        2,
        "/filterRules/%{ruleId}/%{filterKey}/value"
      )

    endpoint_id = endpoint.endpoint_id
    interface_id = Astarte.Core.CQLUtils.interface_id("com.ispirata.Hemera.DeviceLog.Status", 2)

    assert endpoint.interface_name == "com.ispirata.Hemera.DeviceLog.Status"
    assert endpoint.interface_major_version == 2
    assert endpoint.interface_minor_version == 1
    assert endpoint.interface_type == :properties
    assert endpoint.allow_unset == true
    assert endpoint.value_type == :string

    params = %{interface_id: interface_id, endpoint_id: endpoint_id}
    Repo.query!(@insert_devicelog_status_0, params)
    Repo.query!(@insert_devicelog_status_1, params)

    {:ok, device_id_uuid} =
      UUID.cast("536be249-aaaa-4e02-9583-5a4833cbfe49")

    query =
      from e in IndividualProperty,
        prefix: ^keyspace_name,
        where:
          e.device_id == ^device_id_uuid and e.path == "/filterRules/0/testKey/value" and
            e.interface_id == ^interface_id and e.endpoint_id == ^endpoint_id,
        select: %{
          device_id: e.device_id,
          path: e.path,
          reception_timestamp: e.reception_timestamp,
          string_value: e.string_value
        }

    entry = Repo.all(query, consistency: Consistency.domain_model(:read))

    assert entry == [
             %{
               device_id:
                 <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>,
               path: "/filterRules/0/testKey/value",
               reception_timestamp: ~U[2012-02-03 04:06:00.000Z],
               string_value: "T€ST_VÆLÙE"
             }
           ]

    query =
      from i in IndividualProperty,
        prefix: ^keyspace_name,
        where:
          i.device_id == ^device_id_uuid and i.interface_id == ^interface_id and
            i.endpoint_id == ^endpoint_id,
        select: %{path: i.path}

    entries = Repo.all(query, consistency: Consistency.domain_model(:read))

    assert entries == [
             %{path: "/filterRules/0/testKey/value"},
             %{path: "/filterRules/1/testKey2/value"}
           ]
  end

  test "timestamp handling" do
    json_obj = Jason.decode!(@individual_datastream_with_explicit_timestamp_interface_json)
    interface_changeset = InterfaceDocument.changeset(%InterfaceDocument{}, json_obj)
    {:ok, doc} = Ecto.Changeset.apply_action(interface_changeset, :insert)

    {:ok, automaton} = Astarte.Core.Mapping.EndpointsAutomaton.build(doc.mappings)
    Queries.install_new_interface(@test_realm, doc, automaton)

    endpoint_id = retrieve_endpoint_id("com.timestamp.Test", 1, "/test/0/v")

    timestamp_handling_insert_values(endpoint_id, 0, 100)
    timestamp_handling_insert_values(endpoint_id, 1, 20)
    timestamp_handling_insert_values(endpoint_id, 2, 10)

    assert timestamp_handling_check_order(endpoint_id, 0) == {100, true}
    assert timestamp_handling_check_order(endpoint_id, 1) == {20, true}
    assert timestamp_handling_check_order(endpoint_id, 2) == {10, true}
  end

  defp timestamp_handling_insert_values(_endpoint_id, _ind, 0) do
  end

  defp timestamp_handling_insert_values(endpoint_id, ind, n) do
    statement =
      @insert_timestamp_test_value
      |> String.replace(":ind", Integer.to_string(ind))

    interface_id = CQLUtils.interface_id("com.timestamp.Test", 1)
    value_timestamp = 1_504_800_339_954 + Enum.random(0..157_700_000_000)
    reception_timestamp = 1_504_800_339_954 + Enum.random(0..157_700_000_000)

    params = %{
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      value_timestamp: value_timestamp,
      reception_timestamp: reception_timestamp,
      reception_timestamp_submillis: 0,
      num: n
    }

    Repo.query!(statement, params)

    timestamp_handling_insert_values(endpoint_id, ind, n - 1)
  end

  defp timestamp_handling_check_order(endpoint_id, ind) do
    keyspace_name = Realm.keyspace_name(@test_realm)

    path = "/test/#{ind}/v"

    {:ok, device_id_uuid} =
      UUID.cast("536be249-aaaa-4e02-9583-5a4833cbfe49")

    interface_id = Astarte.Core.CQLUtils.interface_id("com.timestamp.Test", 1)

    query =
      from i in IndividualDatastream,
        prefix: ^keyspace_name,
        where:
          i.device_id == ^device_id_uuid and i.interface_id == ^interface_id and
            i.endpoint_id == ^endpoint_id and i.path == ^path,
        select: %{value_timestamp: i.value_timestamp}

    timestamps = Repo.all(query, consistency: Consistency.domain_model(:read))

    sorted_timestamps = Enum.sort_by(timestamps, & &1.value_timestamp, DateTime)

    {length(timestamps), timestamps == sorted_timestamps}
  end

  test "get JWT public key PEM" do
    assert Queries.get_jwt_public_key_pem(@test_realm) ==
             {:ok, DatabaseTestHelper.jwt_public_key_pem_fixture()}
  end

  test "update JWT public key PEM" do
    new_pem = "not_exactly_a_PEM_but_will_do"
    assert Queries.update_jwt_public_key_pem(@test_realm, new_pem) == :ok
    assert Queries.get_jwt_public_key_pem(@test_realm) == {:ok, new_pem}

    # Put the PEM fixture back
    assert Queries.update_jwt_public_key_pem(
             @test_realm,
             DatabaseTestHelper.jwt_public_key_pem_fixture()
           ) == :ok

    assert Queries.get_jwt_public_key_pem(@test_realm) ==
             {:ok, DatabaseTestHelper.jwt_public_key_pem_fixture()}
  end

  test "retrieve and delete individual datastreams for a device" do
    device_id = :crypto.strong_rand_bytes(16)
    interface_name = "com.an.individual.datastream.Interface"
    interface_major = 0
    endpoint = "/%{sensorId}/value"
    path = "/0/value"

    DatabaseTestHelper.seed_individual_datastream_test_data!(
      realm_name: @test_realm,
      device_id: device_id,
      interface_name: interface_name,
      interface_major: interface_major,
      endpoint: endpoint,
      path: path
    )

    assert [
             %{
               device_id: ^device_id,
               interface_id: interface_id,
               endpoint_id: endpoint_id,
               path: ^path
             }
           ] =
             Queries.retrieve_individual_datastreams_keys!(
               @test_realm,
               device_id
             )

    assert ^interface_id = CQLUtils.interface_id(interface_name, interface_major)

    assert ^endpoint_id = CQLUtils.endpoint_id(interface_name, interface_major, endpoint)

    assert :ok =
             Queries.delete_individual_datastream_values!(
               @test_realm,
               device_id,
               interface_id,
               endpoint_id,
               path
             )

    assert [] =
             Queries.retrieve_individual_datastreams_keys!(
               @test_realm,
               device_id
             )
  end

  test "retrieve and delete individual properties for a device" do
    device_id = :crypto.strong_rand_bytes(16)
    interface_name = "com.an.individual.property.Interface"
    interface_major = 0

    DatabaseTestHelper.seed_individual_properties_test_data!(
      realm_name: @test_realm,
      device_id: device_id,
      interface_name: interface_name,
      interface_major: interface_major
    )

    assert [
             %{
               device_id: ^device_id,
               interface_id: interface_id
             }
           ] =
             Queries.retrieve_individual_properties_keys!(
               @test_realm,
               device_id
             )

    assert ^interface_id = CQLUtils.interface_id(interface_name, interface_major)

    assert :ok =
             Queries.delete_individual_properties_values!(
               @test_realm,
               device_id,
               interface_id
             )

    assert [] =
             Queries.retrieve_individual_properties_keys!(
               @test_realm,
               device_id
             )
  end

  test "retrieve and delete object datastreams for a device" do
    interface_name = "com.object.datastream.Interface"
    interface_major = 0
    device_id = :crypto.strong_rand_bytes(16)
    path = "/0/value"

    table_name = CQLUtils.interface_name_to_table_name(interface_name, interface_major)
    DatabaseTestHelper.create_object_datastream_table!(table_name)

    DatabaseTestHelper.seed_object_datastream_test_data!(
      realm_name: @test_realm,
      device_id: device_id,
      interface_name: interface_name,
      interface_major: interface_major,
      path: path
    )

    assert [
             %{
               device_id: ^device_id,
               path: ^path
             }
           ] =
             Queries.retrieve_object_datastream_keys!(
               @test_realm,
               device_id,
               table_name
             )

    assert :ok =
             Queries.delete_object_datastream_values!(
               @test_realm,
               device_id,
               path,
               table_name
             )

    assert [] =
             Queries.retrieve_object_datastream_keys!(
               @test_realm,
               device_id,
               table_name
             )
  end

  test "retrieve device introspection" do
    device_id = :crypto.strong_rand_bytes(16)
    interface_name = "com.an.object.datastream.Interface"
    interface_major = 0

    DatabaseTestHelper.add_interface_to_introspection!(
      realm_name: @test_realm,
      device_id: device_id,
      interface_name: interface_name,
      interface_major: interface_major
    )

    assert %{^interface_name => ^interface_major} =
             Queries.retrieve_device_introspection_map!(
               @test_realm,
               device_id
             )
  end

  test "retrieve interface from introspection" do
    interface_name = "com.an.object.datastream.Interface"
    interface_major = 0

    DatabaseTestHelper.seed_interfaces_table_object_test_data!(
      realm_name: @test_realm,
      interface_name: interface_name,
      interface_major: interface_major
    )

    assert %Astarte.Core.InterfaceDescriptor{
             name: ^interface_name,
             major_version: ^interface_major
           } =
             Queries.retrieve_interface_descriptor!(
               @test_realm,
               interface_name,
               interface_major
             )
  end

  test "retrieve and delete aliases" do
    device_id = :crypto.strong_rand_bytes(16)
    device_alias = "a boring device alias"

    DatabaseTestHelper.seed_aliases_test_data!(
      realm_name: @test_realm,
      device_id: device_id,
      device_alias: device_alias
    )

    assert [
             %{
               object_name: ^device_alias
             }
           ] = Queries.retrieve_aliases!(@test_realm, device_id)

    assert :ok =
             Queries.delete_alias_values!(
               @test_realm,
               device_alias
             )

    assert [] = Queries.retrieve_aliases!(@test_realm, device_id)
  end

  test "retrieve and delete groups" do
    device_id = :crypto.strong_rand_bytes(16)
    {insertion_uuid, _state} = :uuid.get_v1(:uuid.new(self()))
    group = "group"

    DatabaseTestHelper.seed_groups_test_data!(
      realm_name: @test_realm,
      group_name: group,
      insertion_uuid: insertion_uuid,
      device_id: device_id
    )

    assert [
             %{
               device_id: ^device_id,
               insertion_uuid: ^insertion_uuid,
               group_name: ^group
             }
           ] = Queries.retrieve_groups_keys!(@test_realm, device_id)

    assert :ok =
             Queries.delete_group_values!(
               @test_realm,
               device_id,
               group,
               insertion_uuid
             )

    assert [] = Queries.retrieve_groups_keys!(@test_realm, device_id)
  end

  test "retrieve and delete kv_store entries" do
    interface_name = "com.an.individual.datastream.Interface"
    group = "devices-with-data-on-interface-#{interface_name}-v0"

    device_id = :crypto.strong_rand_bytes(16)
    encoded_device_id = Astarte.Core.Device.encode_device_id(device_id)

    DatabaseTestHelper.seed_kv_store_test_data!(
      realm_name: @test_realm,
      group: group,
      key: encoded_device_id
    )

    assert [
             %{
               group: ^group,
               key: ^encoded_device_id
             }
           ] = Queries.retrieve_kv_store_entries!(@test_realm, encoded_device_id)

    assert :ok =
             Queries.delete_kv_store_entry!(
               @test_realm,
               group,
               encoded_device_id
             )

    assert [] = Queries.retrieve_kv_store_entries!(@test_realm, encoded_device_id)
  end

  test "retrieve device registration limit for an existing realm" do
    limit = 10

    DatabaseTestHelper.seed_realm_test_data!(
      realm_name: @test_realm,
      device_registration_limit: limit
    )

    assert {:ok, ^limit} = Queries.get_device_registration_limit(@test_realm)
  end

  test "fail to retrieve device registration limit if realm does not exist" do
    realm_name = "realm#{System.unique_integer([:positive])}"
    assert {:error, :realm_not_found} = Queries.get_device_registration_limit(realm_name)
  end

  test "retrieve datastream_maximum_storage_retention for an existing realm" do
    retention = 10

    DatabaseTestHelper.seed_realm_test_data!(
      realm_name: @test_realm,
      datastream_maximum_storage_retention: retention
    )

    assert {:ok, ^retention} = Queries.get_datastream_maximum_storage_retention(@test_realm)
  end

  test "fail to retrieve datastream_maximum_storage_retention if realm does not exist" do
    realm_name = "realm#{System.unique_integer([:positive])}"

    assert_raise Xandra.Error, fn ->
      Queries.get_datastream_maximum_storage_retention(realm_name)
    end
  end
end
