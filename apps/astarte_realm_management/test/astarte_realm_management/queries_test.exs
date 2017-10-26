defmodule Astarte.RealmManagement.QueriesTest do
  use ExUnit.Case
  require Logger
  alias CQEx.Query, as: DatabaseQuery

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
      (device_id, reception_timestamp, reception_timestamp_submillis, message, timestamp, monotonictimestamp, applicationid, pid, cmdline)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, '2010-02-04 04:05+0000', 0, 'test', '2010-02-03 04:05+0000', 9123456789012345678, 'com.test', 5, '/bin/test')
  """

  @insert_log_line1_device_a """
    INSERT INTO com_ispirata_hemera_devicelog_v1
      (device_id, reception_timestamp, reception_timestamp_submillis, message, timestamp, monotonictimestamp, applicationid, pid, cmdline)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, '2012-02-04 04:06+0000', 0, 'testです', '2012-02-03 04:06+0000', -1, 'this.is.a.bit.longer.string', -2, '/usr/bin/things/test')
  """

  @insert_log_line0_device_b """
    INSERT INTO com_ispirata_hemera_devicelog_v1
      (device_id, reception_timestamp, reception_timestamp_submillis, message, timestamp, monotonictimestamp, applicationid, pid, cmdline)
      VALUES (536be249-bbbb-4e02-9583-5a4833cbfe49, '2012-02-03 04:06+0000', 0, 'testです', '2010-02-03 04:06+0000', -1, 'this.is.a.bit.longer.string', -2, '/usr/bin/things/test')
  """

  @count_log_entries_for_device_a """
    SELECT COUNT(*) FROM autotestrealm.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49;
  """

  @count_log_entries_for_device_b """
    SELECT COUNT(*) FROM autotestrealm.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-bbbb-4e02-9583-5a4833cbfe49;
  """

  @count_log_entries_for_device_c """
    SELECT COUNT(*) FROM autotestrealm.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-cccc-4e02-9583-5a4833cbfe49;
  """

  @a_log_entry_for_device_a """
    SELECT * FROM autotestrealm.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND reception_timestamp > '2011-02-03 04:05+0000';
  """

  @an_older_log_entry_for_device_a """
    SELECT * FROM autotestrealm.com_ispirata_hemera_devicelog_v1 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND reception_timestamp <= '2011-02-03 04:05+0000';
  """

  @individual_property_thing_owned_interface """
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
    INSERT INTO individual_property (device_id, interface_id, endpoint_id, path, endpoint_tokens, reception_timestamp, reception_timestamp_submillis, string_value) VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/filterRules/0/testKey/value', ['0', 'testKey'], '2012-02-03 04:06+0000', 0, 'T€ST_VÆLÙE') ;
  """

  @insert_devicelog_status_1 """
    INSERT INTO individual_property (device_id, interface_id, endpoint_id, path, endpoint_tokens, reception_timestamp, reception_timestamp_submillis, string_value) VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/filterRules/1/testKey2/value', ['1', 'testKey2'], '2012-02-03 04:06+0000', 0, 'test') ;
  """

  @find_devicelog_status_entry """
    SELECT device_id, path, endpoint_tokens, reception_timestamp, string_value FROM individual_property WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path='/filterRules/0/testKey/value';
  """

  @find_devicelog_status_entries """
    SELECT path FROM individual_property WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND interface_id=:interface_id AND endpoint_id=:endpoint_id;
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
    INSERT INTO individual_datastream (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, longinteger_value)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :interface_id, :endpoint_id, '/test/:ind/v', :value_timestamp, :reception_timestamp, :num) ;
    """

  @list_endpoints_by_interface """
    SELECT * FROM endpoints WHERE interface_id = :interface_id;
  """

  @find_interface_by_interface_name """
    SELECT * FROM interfaces WHERE name = :name AND major_version = :major_version;
  """

  @list_timestamp_test_values """
    SELECT value_timestamp FROM individual_datastream WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path='/test/:ind/v';
  """

  def connect_to_test_realm(realm) do
    CQEx.Client.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm])
  end

  def retrieve_endpoint_id(client, interface_name, interface_major, path) do
    query =
      DatabaseQuery.new
      |> DatabaseQuery.statement(@find_interface_by_interface_name)
      |> DatabaseQuery.put(:name, interface_name)
      |> DatabaseQuery.put(:major_version, interface_major)

    interface_row =
      DatabaseQuery.call!(client, query)
      |> Enum.take(1)
      |> hd

    automaton = {:erlang.binary_to_term(interface_row[:automaton_transitions]), :erlang.binary_to_term(interface_row[:automaton_accepting_states])}
    {:ok, endpoint_id} = Astarte.Core.Mapping.EndpointsAutomaton.resolve_path(path, automaton)

    endpoint_id
  end

  def find_endpoint(client, interface_name, interface_major, endpoint) do
    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@list_endpoints_by_interface)
      |> DatabaseQuery.put(:interface_id, Astarte.Core.CQLUtils.interface_id(interface_name, interface_major))

    DatabaseQuery.call!(client, query)
      |> Enum.to_list
      |> Enum.find(fn(row) ->
        row[:endpoint] == endpoint
      end)
  end

  test "object interface install" do
    case Astarte.RealmManagement.DatabaseTestHelper.connect_to_test_database() do
      {:ok, _} ->
        client = connect_to_test_realm("autotestrealm")

        {:ok, intdoc} = Astarte.Core.InterfaceDocument.from_json(@object_datastream_interface_json)
        {:ok, automaton} = Astarte.Core.Mapping.EndpointsAutomaton.build(intdoc.mappings)

        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == false
        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version - 1) == false
        assert Astarte.RealmManagement.Queries.interface_available_versions(client, intdoc.descriptor.name) == []
        assert Astarte.RealmManagement.Queries.interface_source(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == {:error, :interface_not_found}
        assert Astarte.RealmManagement.Queries.get_interfaces_list(client) == []

        Astarte.RealmManagement.Queries.install_new_interface(client, intdoc, automaton)

        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == true
        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version - 1) == false
        assert Astarte.RealmManagement.Queries.interface_available_versions(client, intdoc.descriptor.name) == [[major_version: intdoc.descriptor.major_version, minor_version: intdoc.descriptor.minor_version]]
        assert Astarte.RealmManagement.Queries.interface_source(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == {:ok, intdoc.source}
        assert Astarte.RealmManagement.Queries.get_interfaces_list(client) == ["com.ispirata.Hemera.DeviceLog"]

        DatabaseQuery.call!(client, @insert_log_line0_device_a)
        DatabaseQuery.call!(client, @insert_log_line1_device_a)
        DatabaseQuery.call!(client, @insert_log_line0_device_b)

        count = DatabaseQuery.call!(client, @count_log_entries_for_device_a)
          |> Enum.to_list
        assert count == [[count: 2]]

        count = DatabaseQuery.call!(client, @count_log_entries_for_device_b)
          |> Enum.to_list
        assert count == [[count: 1]]

        count = DatabaseQuery.call!(client, @count_log_entries_for_device_c)
          |> Enum.to_list
        assert count == [[count: 0]]

        a_log_entry = DatabaseQuery.call!(client, @a_log_entry_for_device_a)
          |> Enum.to_list

        assert a_log_entry == [[device_id: <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>, reception_timestamp: 1328328360000, reception_timestamp_submillis: 0, applicationid: "this.is.a.bit.longer.string", cmdline: "/usr/bin/things/test", message: "testです", monotonictimestamp: -1, pid: -2, timestamp: 1328241960000]]

        an_older_log_entry = DatabaseQuery.call!(client, @an_older_log_entry_for_device_a)
          |> Enum.to_list

        assert an_older_log_entry == [[device_id: <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>, reception_timestamp: 1265256300000, reception_timestamp_submillis: 0, applicationid: "com.test", cmdline: "/bin/test", message: "test", monotonictimestamp: 9123456789012345678, pid: 5, timestamp: 1265169900000]]

        Astarte.RealmManagement.DatabaseTestHelper.destroy_local_test_keyspace()

      {:error, msg} -> Logger.warn "Skipped 'object interface install' test, database engine says: " <> msg
    end
  end

  test "individual interface install" do
    case Astarte.RealmManagement.DatabaseTestHelper.connect_to_test_database() do
      {:ok, _} ->
        client = connect_to_test_realm("autotestrealm")

        {:ok, intdoc} = Astarte.Core.InterfaceDocument.from_json(@individual_property_thing_owned_interface )
        {:ok, automaton} = Astarte.Core.Mapping.EndpointsAutomaton.build(intdoc.mappings)

        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == false
        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version - 1) == false
        assert Astarte.RealmManagement.Queries.interface_available_versions(client, intdoc.descriptor.name) == []
        assert Astarte.RealmManagement.Queries.interface_source(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == {:error, :interface_not_found}
        assert Astarte.RealmManagement.Queries.get_interfaces_list(client) == []

        Astarte.RealmManagement.Queries.install_new_interface(client, intdoc, automaton)

        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == true
        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version - 1) == false
        assert Astarte.RealmManagement.Queries.interface_available_versions(client, intdoc.descriptor.name) == [[major_version: intdoc.descriptor.major_version, minor_version: intdoc.descriptor.minor_version]]
        assert Astarte.RealmManagement.Queries.interface_source(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == {:ok, intdoc.source}
        assert Astarte.RealmManagement.Queries.get_interfaces_list(client) == ["com.ispirata.Hemera.DeviceLog.Status"]

        endpoint = find_endpoint(client, "com.ispirata.Hemera.DeviceLog.Status", 2, "/filterRules/%{ruleId}/%{filterKey}/value")
        endpoint_id = endpoint[:endpoint_id]
        interface_id = Astarte.Core.CQLUtils.interface_id("com.ispirata.Hemera.DeviceLog.Status", 2)

        assert endpoint[:interface_name] == "com.ispirata.Hemera.DeviceLog.Status"
        assert endpoint[:interface_major_version] == 2
        assert endpoint[:interface_minor_version] == 1
        assert endpoint[:interface_type] == 1
        assert endpoint[:allow_unset] == true
        assert endpoint[:value_type] == 7

        query = DatabaseQuery.new
          |> DatabaseQuery.statement(@insert_devicelog_status_0)
          |> DatabaseQuery.put(:interface_id, interface_id)
          |> DatabaseQuery.put(:endpoint_id, endpoint_id)
        DatabaseQuery.call!(client, query)

        query = DatabaseQuery.new
          |> DatabaseQuery.statement(@insert_devicelog_status_1)
          |> DatabaseQuery.put(:interface_id, interface_id)
          |> DatabaseQuery.put(:endpoint_id, endpoint_id)
        DatabaseQuery.call!(client, query)

        query = DatabaseQuery.new
          |> DatabaseQuery.statement(@find_devicelog_status_entry)
          |> DatabaseQuery.put(:interface_id, interface_id)
          |> DatabaseQuery.put(:endpoint_id, endpoint_id)
        entry = DatabaseQuery.call!(client, query)
          |> Enum.to_list

        assert entry == [[device_id: <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>, path: "/filterRules/0/testKey/value", endpoint_tokens: ["0", "testKey"], reception_timestamp: 1328241960000, string_value: "T€ST_VÆLÙE"]]

        query = DatabaseQuery.new
          |> DatabaseQuery.statement(@find_devicelog_status_entries)
          |> DatabaseQuery.put(:interface_id, interface_id)
          |> DatabaseQuery.put(:endpoint_id, endpoint_id)
        entries = DatabaseQuery.call!(client, query)
          |> Enum.to_list

        assert entries == [[path: "/filterRules/0/testKey/value"], [path: "/filterRules/1/testKey2/value"]];

        Astarte.RealmManagement.DatabaseTestHelper.destroy_local_test_keyspace()

      {:error, msg} -> Logger.warn "Skipped 'individual interface install' test, database engine says: " <> msg
    end
  end

  test "timestamp handling" do
     case Astarte.RealmManagement.DatabaseTestHelper.connect_to_test_database() do
      {:ok, _} ->
        client = connect_to_test_realm("autotestrealm")

        {:ok, doc} = Astarte.Core.InterfaceDocument.from_json(@individual_datastream_with_explicit_timestamp_interface_json)
        {:ok, automaton} = Astarte.Core.Mapping.EndpointsAutomaton.build(doc.mappings)
        Astarte.RealmManagement.Queries.install_new_interface(client, doc, automaton)

        endpoint_id = retrieve_endpoint_id(client, "com.timestamp.Test", 1, "/test/0/v")

        timestamp_handling_insert_values(client, endpoint_id, 0, 100)
        timestamp_handling_insert_values(client, endpoint_id, 1, 20)
        timestamp_handling_insert_values(client, endpoint_id, 2, 10)

        assert timestamp_handling_check_order(client, endpoint_id, 0) == {100, true}
        assert timestamp_handling_check_order(client, endpoint_id, 1) == {20, true}
        assert timestamp_handling_check_order(client, endpoint_id, 2) == {10, true}

        Astarte.RealmManagement.DatabaseTestHelper.destroy_local_test_keyspace()

      {:error, msg} -> Logger.warn "Skipped 'individual interface install' test, database engine says: " <> msg
    end
  end

  defp timestamp_handling_insert_values(_client, _endpoint_id, _ind, 0) do
  end

  defp timestamp_handling_insert_values(client, endpoint_id, ind, n) do
    statement = @insert_timestamp_test_value
      |> String.replace(":ind", Integer.to_string(ind))

    query = DatabaseQuery.new
      |> DatabaseQuery.statement(statement)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:interface_id, Astarte.Core.CQLUtils.interface_id("com.timestamp.Test", 1))
      |> DatabaseQuery.put(:value_timestamp, 1504800339954 + Enum.random(0..157700000000))
      |> DatabaseQuery.put(:reception_timestamp, 1504800339954 + Enum.random(0..157700000000))
      |> DatabaseQuery.put(:num, n)
    DatabaseQuery.call!(client, query)

    timestamp_handling_insert_values(client, endpoint_id, ind, n - 1)
  end

  defp timestamp_handling_check_order(client, endpoint_id, ind) do
    statement = @list_timestamp_test_values
      |> String.replace(":ind", Integer.to_string(ind))

    query = DatabaseQuery.new
      |> DatabaseQuery.statement(statement)
      |> DatabaseQuery.put(:interface_id, Astarte.Core.CQLUtils.interface_id("com.timestamp.Test", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
    timestamps = DatabaseQuery.call!(client, query)
      |> Enum.to_list

    sorted_timestamps = Enum.sort(timestamps, &(&1[:value_timestamp] <= &2[:value_timestamp]))

    {length(timestamps), timestamps == sorted_timestamps}
  end

end
