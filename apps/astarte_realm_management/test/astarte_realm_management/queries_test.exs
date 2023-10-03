#
# This file is part of Astarte.
#
# Copyright 2017,2018 Ispirata Srl
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
  alias Astarte.Core.Interface, as: InterfaceDocument
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.RealmManagement.DatabaseTestHelper
  alias Astarte.RealmManagement.Queries

  @test_realm_name "autotestrealm"

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
    INSERT INTO #{@test_realm_name}.com_ispirata_hemera_devicelog_v1
      (device_id, path, reception_timestamp, reception_timestamp_submillis, v_message, v_timestamp, v_monotonictimestamp, v_applicationid, v_pid, v_cmdline)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, '/', '2010-02-04 04:05+0000', 0, 'test', '2010-02-03 04:05+0000', 9123456789012345678, 'com.test', 5, '/bin/test')
  """

  @insert_log_line1_device_a """
    INSERT INTO #{@test_realm_name}.com_ispirata_hemera_devicelog_v1
      (device_id, path, reception_timestamp, reception_timestamp_submillis, v_message, v_timestamp, v_monotonictimestamp, v_applicationid, v_pid, v_cmdline)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, '/', '2012-02-04 04:06+0000', 0, 'testです', '2012-02-03 04:06+0000', -1, 'this.is.a.bit.longer.string', -2, '/usr/bin/things/test')
  """

  @insert_log_line0_device_b """
    INSERT INTO #{@test_realm_name}.com_ispirata_hemera_devicelog_v1
      (device_id, path, reception_timestamp, reception_timestamp_submillis, v_message, v_timestamp, v_monotonictimestamp, v_applicationid, v_pid, v_cmdline)
      VALUES (536be249-bbbb-4e02-9583-5a4833cbfe49, '/', '2012-02-03 04:06+0000', 0, 'testです', '2010-02-03 04:06+0000', -1, 'this.is.a.bit.longer.string', -2, '/usr/bin/things/test')
  """

  @count_log_entries_for_device_a """
    SELECT COUNT(*) FROM #{@test_realm_name}.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND path='/';
  """

  @count_log_entries_for_device_b """
    SELECT COUNT(*) FROM #{@test_realm_name}.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-bbbb-4e02-9583-5a4833cbfe49 AND path='/';
  """

  @count_log_entries_for_device_c """
    SELECT COUNT(*) FROM #{@test_realm_name}.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-cccc-4e02-9583-5a4833cbfe49 AND path='/';
  """

  @a_log_entry_for_device_a """
    SELECT * FROM #{@test_realm_name}.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND path='/' AND reception_timestamp > '2011-02-03 04:05+0000';
  """

  @an_older_log_entry_for_device_a """
    SELECT * FROM #{@test_realm_name}.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND path='/' AND reception_timestamp <= '2011-02-03 04:05+0000';
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
  INSERT INTO #{@test_realm_name}.individual_properties
    (device_id, interface_id, endpoint_id, path, reception_timestamp, reception_timestamp_submillis, string_value)
    VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/filterRules/0/testKey/value', '2012-02-03 04:06+0000', 0, 'T€ST_VÆLÙE')
  """

  @insert_devicelog_status_1 """
  INSERT INTO #{@test_realm_name}.individual_properties
    (device_id, interface_id, endpoint_id, path, reception_timestamp, reception_timestamp_submillis, string_value)
    VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/filterRules/1/testKey2/value', '2012-02-03 04:06+0000', 0, 'test')
  """

  @find_devicelog_status_entry """
  SELECT device_id, path, reception_timestamp, string_value
  FROM #{@test_realm_name}.individual_properties
  WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path='/filterRules/0/testKey/value'
  """

  @find_devicelog_status_entries """
    SELECT path FROM #{@test_realm_name}.individual_properties WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND interface_id=:interface_id AND endpoint_id=:endpoint_id;
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
  INSERT INTO #{@test_realm_name}.individual_datastreams (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, longinteger_value)
    VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/test/:ind/v', :value_timestamp, :reception_timestamp, 0, :num) ;
  """

  @list_endpoints_by_interface """
    SELECT * FROM #{@test_realm_name}.endpoints WHERE interface_id = :interface_id;
  """

  @find_interface_by_interface_name """
    SELECT * FROM #{@test_realm_name}.interfaces WHERE name = :name AND major_version = :major_version;
  """

  @list_timestamp_test_values """
    SELECT value_timestamp FROM #{@test_realm_name}.individual_datastreams WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path='/test/:ind/v';
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

    assert Queries.is_interface_major_available?(@test_realm_name, interface_name, major_version) ==
             {:ok, false}

    assert Queries.is_interface_major_available?(
             @test_realm_name,
             interface_name,
             major_version - 1
           ) ==
             {:ok, false}

    assert Queries.interface_available_versions(@test_realm_name, interface_name) ==
             {:error, :interface_not_found}

    assert Queries.get_interfaces_list(@test_realm_name) == {:ok, []}

    Queries.install_new_interface(@test_realm_name, intdoc, automaton)

    assert Queries.is_interface_major_available?(@test_realm_name, interface_name, major_version) ==
             {:ok, true}

    assert Queries.is_interface_major_available?(
             @test_realm_name,
             interface_name,
             major_version - 1
           ) ==
             {:ok, false}

    assert Queries.interface_available_versions(@test_realm_name, interface_name) ==
             {:ok,
              [
                %{
                  major_version: major_version,
                  minor_version: minor_version
                }
              ]}

    assert Queries.get_interfaces_list(@test_realm_name) ==
             {:ok, ["com.ispirata.Hemera.DeviceLog"]}

    execute_query!(@insert_log_line0_device_a)
    execute_query!(@insert_log_line1_device_a)
    execute_query!(@insert_log_line0_device_b)

    count =
      execute_query!(@count_log_entries_for_device_a)
      |> Enum.to_list()

    assert count == [%{count: 2}]

    count =
      execute_query!(@count_log_entries_for_device_b)
      |> Enum.to_list()

    assert count == [%{count: 1}]

    count =
      execute_query!(@count_log_entries_for_device_c)
      |> Enum.to_list()

    assert count == [%{count: 0}]

    a_log_entry =
      execute_query!(@a_log_entry_for_device_a)
      |> Enum.to_list()

    assert a_log_entry == [
             %{
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
             }
           ]

    an_older_log_entry =
      execute_query!(@an_older_log_entry_for_device_a)
      |> Enum.to_list()

    assert an_older_log_entry == [
             %{
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
             }
           ]

    execute_query!("DROP TABLE #{@test_realm_name}.com_ispirata_hemera_devicelog_v1")
  end

  test "individual interface install" do
    json_obj = Jason.decode!(@individual_property_device_owned_interface)
    interface_changeset = InterfaceDocument.changeset(%InterfaceDocument{}, json_obj)
    {:ok, intdoc} = Ecto.Changeset.apply_action(interface_changeset, :insert)

    %{
      name: interface_name,
      major_version: major_version,
      minor_version: minor_version
    } = InterfaceDescriptor.from_interface(intdoc)

    {:ok, automaton} = Astarte.Core.Mapping.EndpointsAutomaton.build(intdoc.mappings)

    assert Queries.is_interface_major_available?(@test_realm_name, interface_name, major_version) ==
             {:ok, false}

    assert Queries.is_interface_major_available?(
             @test_realm_name,
             interface_name,
             major_version - 1
           ) ==
             {:ok, false}

    assert Queries.interface_available_versions(@test_realm_name, interface_name) ==
             {:error, :interface_not_found}

    assert Queries.get_interfaces_list(@test_realm_name) == {:ok, []}

    Queries.install_new_interface(@test_realm_name, intdoc, automaton)

    assert Queries.is_interface_major_available?(@test_realm_name, interface_name, major_version) ==
             {:ok, true}

    assert Queries.is_interface_major_available?(
             @test_realm_name,
             interface_name,
             major_version - 1
           ) ==
             {:ok, false}

    assert Queries.interface_available_versions(@test_realm_name, interface_name) ==
             {:ok,
              [
                %{
                  major_version: major_version,
                  minor_version: minor_version
                }
              ]}

    assert Queries.get_interfaces_list(@test_realm_name) ==
             {:ok, ["com.ispirata.Hemera.DeviceLog.Status"]}

    endpoint =
      find_endpoint(
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

    params = %{interface_id: interface_id, endpoint_id: endpoint_id}
    execute_query!(@insert_devicelog_status_0, params)

    execute_query!(@insert_devicelog_status_1, params)

    entry =
      execute_query!(@find_devicelog_status_entry, params)
      |> Enum.to_list()

    assert entry == [
             %{
               device_id:
                 <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>,
               path: "/filterRules/0/testKey/value",
               reception_timestamp: 1_328_241_960_000,
               string_value: "T€ST_VÆLÙE"
             }
           ]

    entries =
      execute_query!(@find_devicelog_status_entries, params)
      |> Enum.to_list()

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
    Queries.install_new_interface(@test_realm_name, doc, automaton)

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

    params = %{
      endpoint_id: endpoint_id,
      interface_id: Astarte.Core.CQLUtils.interface_id("com.timestamp.Test", 1),
      value_timestamp: 1_504_800_339_954 + Enum.random(0..157_700_000_000),
      reception_timestamp: 1_504_800_339_954 + Enum.random(0..157_700_000_000),
      num: n
    }

    execute_query!(statement, params)

    timestamp_handling_insert_values(endpoint_id, ind, n - 1)
  end

  defp timestamp_handling_check_order(endpoint_id, ind) do
    statement =
      @list_timestamp_test_values
      |> String.replace(":ind", Integer.to_string(ind))

    params = %{
      interface_id: Astarte.Core.CQLUtils.interface_id("com.timestamp.Test", 1),
      endpoint_id: endpoint_id
    }

    timestamps =
      execute_query!(statement, params)
      |> Enum.to_list()

    sorted_timestamps = Enum.sort(timestamps, &(&1[:value_timestamp] <= &2[:value_timestamp]))

    {length(timestamps), timestamps == sorted_timestamps}
  end

  test "get JWT public key PEM" do
    assert Queries.get_jwt_public_key_pem(@test_realm_name) ==
             {:ok, DatabaseTestHelper.jwt_public_key_pem_fixture()}
  end

  test "update JWT public key PEM" do
    new_pem = "not_exactly_a_PEM_but_will_do"
    assert Queries.update_jwt_public_key_pem(@test_realm_name, new_pem) == :ok
    assert Queries.get_jwt_public_key_pem(@test_realm_name) == {:ok, new_pem}

    # Put the PEM fixture back
    assert Queries.update_jwt_public_key_pem(
             @test_realm_name,
             DatabaseTestHelper.jwt_public_key_pem_fixture()
           ) == :ok

    assert Queries.get_jwt_public_key_pem(@test_realm_name) ==
             {:ok, DatabaseTestHelper.jwt_public_key_pem_fixture()}
  end

  defp retrieve_endpoint_id(interface_name, interface_major, path) do
    params = %{name: interface_name, major_version: interface_major}

    interface_row =
      execute_query!(@find_interface_by_interface_name, params)
      |> Enum.to_list()
      |> hd

    automaton =
      {:erlang.binary_to_term(interface_row[:automaton_transitions]),
       :erlang.binary_to_term(interface_row[:automaton_accepting_states])}

    {:ok, endpoint_id} = Astarte.Core.Mapping.EndpointsAutomaton.resolve_path(path, automaton)

    endpoint_id
  end

  defp find_endpoint(interface_name, interface_major, endpoint) do
    params = %{
      interface_id: Astarte.Core.CQLUtils.interface_id(interface_name, interface_major)
    }

    interface_row =
      execute_query!(@list_endpoints_by_interface, params)
      |> Enum.to_list()
      |> Enum.find(fn row ->
        row[:endpoint] == endpoint
      end)
  end

  defp execute_query!(statement, params \\ %{}) do
    Xandra.Cluster.run(
      :xandra,
      fn conn ->
        {:ok, prepared} = Xandra.prepare(conn, statement)
        Xandra.execute!(conn, prepared, params, uuid_format: :binary, timestamp_format: :integer)
      end
    )
  end
end
