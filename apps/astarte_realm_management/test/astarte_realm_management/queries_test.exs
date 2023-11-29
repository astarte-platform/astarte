#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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
  require Logger
  alias Astarte.RealmManagement.DatabaseFixtures
  alias CQEx.Query, as: DatabaseQuery
  alias Astarte.Core.Interface, as: InterfaceDocument
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.RealmManagement.DatabaseTestHelper
  alias Astarte.RealmManagement.Queries
  alias Astarte.RealmManagement.Config
  alias Astarte.Core.CQLUtils

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
    INSERT INTO com_ispirata_hemera_devicelog_v1
      (device_id, path, reception_timestamp, reception_timestamp_submillis, v_message, v_timestamp, v_monotonictimestamp, v_applicationid, v_pid, v_cmdline)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, '/', '2010-02-04 04:05+0000', 0, 'test', '2010-02-03 04:05+0000', 9123456789012345678, 'com.test', 5, '/bin/test')
  """

  @insert_log_line1_device_a """
    INSERT INTO com_ispirata_hemera_devicelog_v1
      (device_id, path, reception_timestamp, reception_timestamp_submillis, v_message, v_timestamp, v_monotonictimestamp, v_applicationid, v_pid, v_cmdline)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, '/', '2012-02-04 04:06+0000', 0, 'testです', '2012-02-03 04:06+0000', -1, 'this.is.a.bit.longer.string', -2, '/usr/bin/things/test')
  """

  @insert_log_line0_device_b """
    INSERT INTO com_ispirata_hemera_devicelog_v1
      (device_id, path, reception_timestamp, reception_timestamp_submillis, v_message, v_timestamp, v_monotonictimestamp, v_applicationid, v_pid, v_cmdline)
      VALUES (536be249-bbbb-4e02-9583-5a4833cbfe49, '/', '2012-02-03 04:06+0000', 0, 'testです', '2010-02-03 04:06+0000', -1, 'this.is.a.bit.longer.string', -2, '/usr/bin/things/test')
  """

  @count_log_entries_for_device_a """
    SELECT COUNT(*) FROM autotestrealm.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND path='/';
  """

  @count_log_entries_for_device_b """
    SELECT COUNT(*) FROM autotestrealm.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-bbbb-4e02-9583-5a4833cbfe49 AND path='/';
  """

  @count_log_entries_for_device_c """
    SELECT COUNT(*) FROM autotestrealm.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-cccc-4e02-9583-5a4833cbfe49 AND path='/';
  """

  @a_log_entry_for_device_a """
    SELECT * FROM autotestrealm.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND path='/' AND reception_timestamp > '2011-02-03 04:05+0000';
  """

  @an_older_log_entry_for_device_a """
    SELECT * FROM autotestrealm.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND path='/' AND reception_timestamp <= '2011-02-03 04:05+0000';
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
  INSERT INTO individual_properties
    (device_id, interface_id, endpoint_id, path, reception_timestamp, reception_timestamp_submillis, string_value)
    VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/filterRules/0/testKey/value', '2012-02-03 04:06+0000', 0, 'T€ST_VÆLÙE')
  """

  @insert_devicelog_status_1 """
  INSERT INTO individual_properties
    (device_id, interface_id, endpoint_id, path, reception_timestamp, reception_timestamp_submillis, string_value)
    VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/filterRules/1/testKey2/value', '2012-02-03 04:06+0000', 0, 'test')
  """

  @find_devicelog_status_entry """
  SELECT device_id, path, reception_timestamp, string_value
  FROM individual_properties
  WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path='/filterRules/0/testKey/value'
  """

  @find_devicelog_status_entries """
    SELECT path FROM individual_properties WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND interface_id=:interface_id AND endpoint_id=:endpoint_id;
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
  INSERT INTO individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, longinteger_value)
    VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/test/:ind/v', :value_timestamp, :reception_timestamp, 0, :num) ;
  """

  @list_endpoints_by_interface """
    SELECT * FROM endpoints WHERE interface_id = :interface_id;
  """

  @find_interface_by_interface_name """
    SELECT * FROM interfaces WHERE name = :name AND major_version = :major_version;
  """

  @list_timestamp_test_values """
    SELECT value_timestamp FROM individual_datastreams WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path='/test/:ind/v';
  """

  @realm_name "autotestrealm"

  setup do
    with {:ok, client} <- DatabaseTestHelper.connect_to_test_database() do
      DatabaseTestHelper.seed_test_data(client)
    end
  end

  setup_all do
    with {:ok, client} <- DatabaseTestHelper.connect_to_test_database() do
      DatabaseTestHelper.create_test_keyspace(client)
    end

    on_exit(fn ->
      with {:ok, client} <- DatabaseTestHelper.connect_to_test_database() do
        DatabaseTestHelper.drop_test_keyspace(client)
      end
    end)
  end

  def connect_to_test_realm(realm) do
    cqex_options =
      Config.cqex_options!()
      |> Keyword.put(:keyspace, realm)

    CQEx.Client.new!(Config.cassandra_node!(), cqex_options)
  end

  def retrieve_endpoint_id(client, interface_name, interface_major, path) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@find_interface_by_interface_name)
      |> DatabaseQuery.put(:name, interface_name)
      |> DatabaseQuery.put(:major_version, interface_major)

    interface_row =
      DatabaseQuery.call!(client, query)
      |> Enum.take(1)
      |> hd

    automaton =
      {:erlang.binary_to_term(interface_row[:automaton_transitions]),
       :erlang.binary_to_term(interface_row[:automaton_accepting_states])}

    {:ok, endpoint_id} = Astarte.Core.Mapping.EndpointsAutomaton.resolve_path(path, automaton)

    endpoint_id
  end

  def find_endpoint(client, interface_name, interface_major, endpoint) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@list_endpoints_by_interface)
      |> DatabaseQuery.put(
        :interface_id,
        Astarte.Core.CQLUtils.interface_id(interface_name, interface_major)
      )

    DatabaseQuery.call!(client, query)
    |> Enum.to_list()
    |> Enum.find(fn row ->
      row[:endpoint] == endpoint
    end)
  end

  test "object interface install" do
    {:ok, _} = DatabaseTestHelper.connect_to_test_database()
    client = connect_to_test_realm("autotestrealm")

    json_obj = Jason.decode!(@object_datastream_interface_json)
    interface_changeset = InterfaceDocument.changeset(%InterfaceDocument{}, json_obj)
    {:ok, intdoc} = Ecto.Changeset.apply_action(interface_changeset, :insert)

    %{
      name: interface_name,
      major_version: major_version,
      minor_version: minor_version
    } = InterfaceDescriptor.from_interface(intdoc)

    {:ok, automaton} = Astarte.Core.Mapping.EndpointsAutomaton.build(intdoc.mappings)

    assert Queries.is_interface_major_available?(client, interface_name, major_version) ==
             {:ok, false}

    assert Queries.is_interface_major_available?(client, interface_name, major_version - 1) ==
             {:ok, false}

    assert Queries.interface_available_versions(client, interface_name) ==
             {:error, :interface_not_found}

    assert Queries.get_interfaces_list(client) == {:ok, []}

    Queries.install_new_interface(client, intdoc, automaton)

    assert Queries.is_interface_major_available?(client, interface_name, major_version) ==
             {:ok, true}

    assert Queries.is_interface_major_available?(client, interface_name, major_version - 1) ==
             {:ok, false}

    assert Queries.interface_available_versions(client, interface_name) ==
             {:ok,
              [
                [
                  major_version: major_version,
                  minor_version: minor_version
                ]
              ]}

    assert Queries.get_interfaces_list(client) == {:ok, ["com.ispirata.Hemera.DeviceLog"]}

    DatabaseQuery.call!(client, @insert_log_line0_device_a)
    DatabaseQuery.call!(client, @insert_log_line1_device_a)
    DatabaseQuery.call!(client, @insert_log_line0_device_b)

    count =
      DatabaseQuery.call!(client, @count_log_entries_for_device_a)
      |> Enum.to_list()

    assert count == [[count: 2]]

    count =
      DatabaseQuery.call!(client, @count_log_entries_for_device_b)
      |> Enum.to_list()

    assert count == [[count: 1]]

    count =
      DatabaseQuery.call!(client, @count_log_entries_for_device_c)
      |> Enum.to_list()

    assert count == [[count: 0]]

    a_log_entry =
      DatabaseQuery.call!(client, @a_log_entry_for_device_a)
      |> Enum.to_list()

    assert a_log_entry == [
             [
               device_id:
                 <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>,
               path: "/",
               reception_timestamp: 1_328_328_360_000,
               reception_timestamp_submillis: 0,
               v_applicationid: "this.is.a.bit.longer.string",
               v_cmdline: "/usr/bin/things/test",
               v_message: "testです",
               v_monotonictimestamp: -1,
               v_pid: -2,
               v_timestamp: 1_328_241_960_000
             ]
           ]

    an_older_log_entry =
      DatabaseQuery.call!(client, @an_older_log_entry_for_device_a)
      |> Enum.to_list()

    assert an_older_log_entry == [
             [
               device_id:
                 <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>,
               path: "/",
               reception_timestamp: 1_265_256_300_000,
               reception_timestamp_submillis: 0,
               v_applicationid: "com.test",
               v_cmdline: "/bin/test",
               v_message: "test",
               v_monotonictimestamp: 9_123_456_789_012_345_678,
               v_pid: 5,
               v_timestamp: 1_265_169_900_000
             ]
           ]

    DatabaseQuery.call!(client, "DROP TABLE com_ispirata_hemera_devicelog_v1")
  end

  test "individual interface install" do
    {:ok, _} = DatabaseTestHelper.connect_to_test_database()
    client = connect_to_test_realm("autotestrealm")

    json_obj = Jason.decode!(@individual_property_device_owned_interface)
    interface_changeset = InterfaceDocument.changeset(%InterfaceDocument{}, json_obj)
    {:ok, intdoc} = Ecto.Changeset.apply_action(interface_changeset, :insert)

    %{
      name: interface_name,
      major_version: major_version,
      minor_version: minor_version
    } = InterfaceDescriptor.from_interface(intdoc)

    {:ok, automaton} = Astarte.Core.Mapping.EndpointsAutomaton.build(intdoc.mappings)

    assert Queries.is_interface_major_available?(client, interface_name, major_version) ==
             {:ok, false}

    assert Queries.is_interface_major_available?(client, interface_name, major_version - 1) ==
             {:ok, false}

    assert Queries.interface_available_versions(client, interface_name) ==
             {:error, :interface_not_found}

    assert Queries.get_interfaces_list(client) == {:ok, []}

    Queries.install_new_interface(client, intdoc, automaton)

    assert Queries.is_interface_major_available?(client, interface_name, major_version) ==
             {:ok, true}

    assert Queries.is_interface_major_available?(client, interface_name, major_version - 1) ==
             {:ok, false}

    assert Queries.interface_available_versions(client, interface_name) ==
             {:ok,
              [
                [
                  major_version: major_version,
                  minor_version: minor_version
                ]
              ]}

    assert Queries.get_interfaces_list(client) == {:ok, ["com.ispirata.Hemera.DeviceLog.Status"]}

    endpoint =
      find_endpoint(
        client,
        "com.ispirata.Hemera.DeviceLog.Status",
        2,
        "/filterRules/%{ruleId}/%{filterKey}/value"
      )

    endpoint_id = endpoint[:endpoint_id]

    interface_id = Astarte.Core.CQLUtils.interface_id("com.ispirata.Hemera.DeviceLog.Status", 2)

    assert endpoint[:interface_name] == "com.ispirata.Hemera.DeviceLog.Status"
    assert endpoint[:interface_major_version] == 2
    assert endpoint[:interface_minor_version] == 1
    assert endpoint[:interface_type] == 1
    assert endpoint[:allow_unset] == true
    assert endpoint[:value_type] == 7

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_devicelog_status_0)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    DatabaseQuery.call!(client, query)

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_devicelog_status_1)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    DatabaseQuery.call!(client, query)

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@find_devicelog_status_entry)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    entry =
      DatabaseQuery.call!(client, query)
      |> Enum.to_list()

    assert entry == [
             [
               device_id:
                 <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>,
               path: "/filterRules/0/testKey/value",
               reception_timestamp: 1_328_241_960_000,
               string_value: "T€ST_VÆLÙE"
             ]
           ]

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@find_devicelog_status_entries)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    entries =
      DatabaseQuery.call!(client, query)
      |> Enum.to_list()

    assert entries == [
             [path: "/filterRules/0/testKey/value"],
             [path: "/filterRules/1/testKey2/value"]
           ]
  end

  test "timestamp handling" do
    {:ok, _} = DatabaseTestHelper.connect_to_test_database()
    client = connect_to_test_realm("autotestrealm")

    json_obj = Jason.decode!(@individual_datastream_with_explicit_timestamp_interface_json)
    interface_changeset = InterfaceDocument.changeset(%InterfaceDocument{}, json_obj)
    {:ok, doc} = Ecto.Changeset.apply_action(interface_changeset, :insert)

    {:ok, automaton} = Astarte.Core.Mapping.EndpointsAutomaton.build(doc.mappings)
    Queries.install_new_interface(client, doc, automaton)

    endpoint_id = retrieve_endpoint_id(client, "com.timestamp.Test", 1, "/test/0/v")

    timestamp_handling_insert_values(client, endpoint_id, 0, 100)
    timestamp_handling_insert_values(client, endpoint_id, 1, 20)
    timestamp_handling_insert_values(client, endpoint_id, 2, 10)

    assert timestamp_handling_check_order(client, endpoint_id, 0) == {100, true}
    assert timestamp_handling_check_order(client, endpoint_id, 1) == {20, true}
    assert timestamp_handling_check_order(client, endpoint_id, 2) == {10, true}
  end

  defp timestamp_handling_insert_values(_client, _endpoint_id, _ind, 0) do
  end

  defp timestamp_handling_insert_values(client, endpoint_id, ind, n) do
    statement =
      @insert_timestamp_test_value
      |> String.replace(":ind", Integer.to_string(ind))

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(statement)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(
        :interface_id,
        Astarte.Core.CQLUtils.interface_id("com.timestamp.Test", 1)
      )
      |> DatabaseQuery.put(:value_timestamp, 1_504_800_339_954 + Enum.random(0..157_700_000_000))
      |> DatabaseQuery.put(
        :reception_timestamp,
        1_504_800_339_954 + Enum.random(0..157_700_000_000)
      )
      |> DatabaseQuery.put(:num, n)

    DatabaseQuery.call!(client, query)

    timestamp_handling_insert_values(client, endpoint_id, ind, n - 1)
  end

  defp timestamp_handling_check_order(client, endpoint_id, ind) do
    statement =
      @list_timestamp_test_values
      |> String.replace(":ind", Integer.to_string(ind))

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(statement)
      |> DatabaseQuery.put(
        :interface_id,
        Astarte.Core.CQLUtils.interface_id("com.timestamp.Test", 1)
      )
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    timestamps =
      DatabaseQuery.call!(client, query)
      |> Enum.to_list()

    sorted_timestamps = Enum.sort(timestamps, &(&1[:value_timestamp] <= &2[:value_timestamp]))

    {length(timestamps), timestamps == sorted_timestamps}
  end

  test "get JWT public key PEM" do
    DatabaseTestHelper.connect_to_test_database()
    client = connect_to_test_realm("autotestrealm")

    assert Queries.get_jwt_public_key_pem(client) ==
             {:ok, DatabaseTestHelper.jwt_public_key_pem_fixture()}
  end

  test "update JWT public key PEM" do
    DatabaseTestHelper.connect_to_test_database()
    client = connect_to_test_realm("autotestrealm")

    new_pem = "not_exactly_a_PEM_but_will_do"
    assert Queries.update_jwt_public_key_pem(client, new_pem) == :ok
    assert Queries.get_jwt_public_key_pem(client) == {:ok, new_pem}

    # Put the PEM fixture back
    assert Queries.update_jwt_public_key_pem(
             client,
             DatabaseTestHelper.jwt_public_key_pem_fixture()
           ) == :ok

    assert Queries.get_jwt_public_key_pem(client) ==
             {:ok, DatabaseTestHelper.jwt_public_key_pem_fixture()}
  end

  test "retrieve and delete individual datastreams for a device" do
    device_id = :crypto.strong_rand_bytes(16)
    interface_name = "com.an.individual.datastream.Interface"
    interface_major = 0
    endpoint = "/%{sensorId}/value"
    path = "/0/value"

    DatabaseTestHelper.seed_individual_datastream_test_data!(
      realm_name: @realm_name,
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
               @realm_name,
               device_id
             )

    assert ^interface_id = CQLUtils.interface_id(interface_name, interface_major)

    assert ^endpoint_id = CQLUtils.endpoint_id(interface_name, interface_major, endpoint)

    assert %Xandra.Void{} =
             Queries.delete_individual_datastream_values!(
               @realm_name,
               device_id,
               interface_id,
               endpoint_id,
               path
             )

    assert [] =
             Queries.retrieve_individual_datastreams_keys!(
               @realm_name,
               device_id
             )
  end

  test "retrieve and delete individual properties for a device" do
    device_id = :crypto.strong_rand_bytes(16)
    interface_name = "com.an.individual.property.Interface"
    interface_major = 0

    DatabaseTestHelper.seed_individual_properties_test_data!(
      realm_name: @realm_name,
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
               @realm_name,
               device_id
             )

    assert ^interface_id = CQLUtils.interface_id(interface_name, interface_major)

    assert %Xandra.Void{} =
             Queries.delete_individual_properties_values!(
               @realm_name,
               device_id,
               interface_id
             )

    assert [] =
             Queries.retrieve_individual_properties_keys!(
               @realm_name,
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
      realm_name: @realm_name,
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
               @realm_name,
               device_id,
               table_name
             )

    assert %Xandra.Void{} =
             Queries.delete_object_datastream_values!(
               @realm_name,
               device_id,
               path,
               table_name
             )

    assert [] =
             Queries.retrieve_object_datastream_keys!(
               @realm_name,
               device_id,
               table_name
             )
  end

  test "retrieve device introspection" do
    device_id = :crypto.strong_rand_bytes(16)
    interface_name = "com.an.object.datastream.Interface"
    interface_major = 0

    DatabaseTestHelper.add_interface_to_introspection!(
      realm_name: @realm_name,
      device_id: device_id,
      interface_name: interface_name,
      interface_major: interface_major
    )

    assert %{^interface_name => ^interface_major} =
             Queries.retrieve_device_introspection_map!(
               @realm_name,
               device_id
             )
  end

  test "retrieve interface from introspection" do
    interface_name = "com.an.object.datastream.Interface"
    interface_major = 0

    DatabaseTestHelper.seed_interfaces_table_object_test_data!(
      realm_name: @realm_name,
      interface_name: interface_name,
      interface_major: interface_major
    )

    assert %Astarte.Core.InterfaceDescriptor{
             name: ^interface_name,
             major_version: ^interface_major
           } =
             Queries.retrieve_interface_descriptor!(
               @realm_name,
               interface_name,
               interface_major
             )
  end

  test "retrieve and delete aliases" do
    device_id = :crypto.strong_rand_bytes(16)
    device_alias = "a boring device alias"

    DatabaseTestHelper.seed_aliases_test_data!(
      realm_name: @realm_name,
      device_id: device_id,
      device_alias: device_alias
    )

    assert [
             %{
               object_name: ^device_alias
             }
           ] = Queries.retrieve_aliases!(@realm_name, device_id)

    assert %Xandra.Void{} =
             Queries.delete_alias_values!(
               @realm_name,
               device_alias
             )

    assert [] = Queries.retrieve_aliases!(@realm_name, device_id)
  end

  test "retrieve and delete groups" do
    device_id = :crypto.strong_rand_bytes(16)
    {insertion_uuid, _state} = :uuid.get_v1(:uuid.new(self()))
    group = "group"

    DatabaseTestHelper.seed_groups_test_data!(
      realm_name: @realm_name,
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
           ] = Queries.retrieve_groups_keys!(@realm_name, device_id)

    assert %Xandra.Void{} =
             Queries.delete_group_values!(
               @realm_name,
               device_id,
               group,
               insertion_uuid
             )

    assert [] = Queries.retrieve_groups_keys!(@realm_name, device_id)
  end

  test "retrieve and delete kv_store entries" do
    interface_name = "com.an.individual.datastream.Interface"
    group = "devices-with-data-on-interface-#{interface_name}-v0"

    device_id = :crypto.strong_rand_bytes(16)
    encoded_device_id = Astarte.Core.Device.encode_device_id(device_id)

    DatabaseTestHelper.seed_kv_store_test_data!(
      realm_name: @realm_name,
      group: group,
      key: encoded_device_id
    )

    assert [
             %{
               group: ^group,
               key: ^encoded_device_id
             }
           ] = Queries.retrieve_kv_store_entries!(@realm_name, encoded_device_id)

    assert %Xandra.Void{} =
             Queries.delete_kv_store_entry!(
               @realm_name,
               group,
               encoded_device_id
             )

    assert [] = Queries.retrieve_kv_store_entries!(@realm_name, encoded_device_id)
  end

  test "retrieve device registration limit for an existing realm" do
    limit = 10

    DatabaseTestHelper.seed_realm_test_data!(
      realm_name: @realm_name,
      device_registration_limit: limit
    )

    assert {:ok, ^limit} = Queries.get_device_registration_limit(@realm_name)
  end

  test "fail to retrieve device registration limit if realm does not exist" do
    realm_name = "realm#{System.unique_integer([:positive])}"
    assert {:error, :realm_not_found} = Queries.get_device_registration_limit(realm_name)
  end
end
