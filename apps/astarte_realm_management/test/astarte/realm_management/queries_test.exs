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

  @create_autotestrealm """
    CREATE KEYSPACE autotestrealm
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """
  @create_interfaces_table """
      CREATE TABLE autotestrealm.interfaces (
        name ascii,
        major_version int,
        minor_version int,
        type int,
        quality int,
        flags int,
        source varchar,
        PRIMARY KEY (name, major_version)
      );
  """

  @create_endpoints_table """
      CREATE TABLE autotestrealm.endpoints (
        endpoint_id uuid,
        interface_name ascii,
        interface_major_version int,
        interface_minor_version int,
        interface_type int,
        endpoint ascii,
        value_type int,
        reliabilty int,
        retention int,
        expiry int,
        allow_unset boolean,

        PRIMARY KEY (endpoint_id)
      );
  """

  @insert_log_line0_device_a """
    INSERT INTO com_ispirata_hemera_devicelog_v1
      (device_id, reception_timestamp, message, timestamp, monotonictimestamp, applicationid, pid, cmdline)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, '2010-02-04 04:05+0000', 'test', '2010-02-03 04:05+0000', 9123456789012345678, 'com.test', 5, '/bin/test')
  """

  @insert_log_line1_device_a """
    INSERT INTO com_ispirata_hemera_devicelog_v1
      (device_id, reception_timestamp, message, timestamp, monotonictimestamp, applicationid, pid, cmdline)
      VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, '2012-02-04 04:06+0000', 'testです', '2012-02-03 04:06+0000', -1, 'this.is.a.bit.longer.string', -2, '/usr/bin/things/test')
  """

  @insert_log_line0_device_b """
    INSERT INTO com_ispirata_hemera_devicelog_v1
      (device_id, reception_timestamp, message, timestamp, monotonictimestamp, applicationid, pid, cmdline)
      VALUES (536be249-bbbb-4e02-9583-5a4833cbfe49, '2012-02-03 04:06+0000', 'testです', '2010-02-03 04:06+0000', -1, 'this.is.a.bit.longer.string', -2, '/usr/bin/things/test')
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

  #TODO: should we index by endpoint/interface?
  @find_endpoint_id """
    SELECT * FROM endpoints WHERE endpoint = '/filterRules/%{ruleId}/%{filterKey}/value' ALLOW FILTERING;
  """

  @insert_devicelog_status_0 """
    INSERT INTO com_ispirata_hemera_devicelog_status_v2 (device_id, endpoint_id, path, endpoint_tokens, reception_timestamp, string_value) VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :endpoint_id, '/filterRules/0/testKey/value', ['0', 'testKey'], '2012-02-03 04:06+0000', 'T€ST_VÆLÙE') ;
  """

  @insert_devicelog_status_1 """
    INSERT INTO com_ispirata_hemera_devicelog_status_v2 (device_id, endpoint_id, path, endpoint_tokens, reception_timestamp, string_value) VALUES (536be249-aaaa-4e02-9583-5a4833cbfe49, :endpoint_id, '/filterRules/1/testKey2/value', ['1', 'testKey2'], '2012-02-03 04:06+0000', 'test') ;
  """

  @find_devicelog_status_entry """
    SELECT device_id, path, endpoint_tokens, reception_timestamp, string_value FROM com_ispirata_hemera_devicelog_status_v2 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND endpoint_id=:endpoint_id AND path='/filterRules/0/testKey/value';
  """

  @find_devicelog_status_entries """
    SELECT path FROM com_ispirata_hemera_devicelog_status_v2 WHERE device_id=536be249-aaaa-4e02-9583-5a4833cbfe49 AND endpoint_id=:endpoint_id;
  """

  def connect_to_test_database do
    {:ok, client} = CQEx.Client.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)))
    case DatabaseQuery.call(client, @create_autotestrealm) do
      {:ok, _} ->
        DatabaseQuery.call!(client, @create_interfaces_table)
        DatabaseQuery.call!(client, @create_endpoints_table)
        {:ok, client}
      %{msg: msg} -> {:error, msg}
    end
  end

  def connect_to_test_realm(realm) do
    CQEx.Client.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm])
  end

  def destroy_local_test_keyspace do
    {:ok, client} = CQEx.Client.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)))
    DatabaseQuery.call(client, "DROP KEYSPACE autotestrealm;")
    :ok
  end

  test "object interface install" do
    case connect_to_test_database() do
      {:ok, _} ->
        client = connect_to_test_realm("autotestrealm")

        intdoc = Astarte.Core.InterfaceDocument.from_json(@object_datastream_interface_json)

        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == false
        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version - 1) == false
        assert Astarte.RealmManagement.Queries.interface_available_versions(client, intdoc.descriptor.name) == []

        Astarte.RealmManagement.Queries.install_new_interface(client, intdoc)

        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == true
        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version - 1) == false
        assert Astarte.RealmManagement.Queries.interface_available_versions(client, intdoc.descriptor.name) == [[major_version: intdoc.descriptor.major_version, minor_version: intdoc.descriptor.minor_version]]

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

        assert a_log_entry == [[device_id: <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>, reception_timestamp: 1328328360000, applicationid: "this.is.a.bit.longer.string", cmdline: "/usr/bin/things/test", message: "testです", monotonictimestamp: -1, pid: -2, timestamp: 1328241960000]]

        an_older_log_entry = DatabaseQuery.call!(client, @an_older_log_entry_for_device_a)
          |> Enum.to_list

        assert an_older_log_entry == [[device_id: <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>, reception_timestamp: 1265256300000, applicationid: "com.test", cmdline: "/bin/test", message: "test", monotonictimestamp: 9123456789012345678, pid: 5, timestamp: 1265169900000]]

        destroy_local_test_keyspace()

      {:error, msg} -> Logger.warn "Skipped 'object interface install' test, database engine says: " <> msg
    end
  end

  test "individual interface install" do
    case connect_to_test_database() do
      {:ok, _} ->
        client = connect_to_test_realm("autotestrealm")

        intdoc = Astarte.Core.InterfaceDocument.from_json(@individual_property_thing_owned_interface )

        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == false
        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version - 1) == false
        assert Astarte.RealmManagement.Queries.interface_available_versions(client, intdoc.descriptor.name) == []

        Astarte.RealmManagement.Queries.install_new_interface(client, intdoc)

        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version) == true
        assert Astarte.RealmManagement.Queries.is_interface_major_available?(client, intdoc.descriptor.name, intdoc.descriptor.major_version - 1) == false
        assert Astarte.RealmManagement.Queries.interface_available_versions(client, intdoc.descriptor.name) == [[major_version: intdoc.descriptor.major_version, minor_version: intdoc.descriptor.minor_version]]

        endpoint = DatabaseQuery.call!(client, @find_endpoint_id)
          |> Enum.to_list
          |> List.first

        endpoint_id = endpoint[:endpoint_id]

        assert endpoint[:interface_name] == "com.ispirata.Hemera.DeviceLog.Status"
        assert endpoint[:interface_major_version] == 2
        assert endpoint[:interface_minor_version] == 1
        assert endpoint[:interface_type] == 1
        assert endpoint[:allow_unset] == true
        assert endpoint[:value_type] == 7

        query = DatabaseQuery.new
          |> DatabaseQuery.statement(@insert_devicelog_status_0)
          |> DatabaseQuery.put(:endpoint_id, endpoint_id)
        DatabaseQuery.call!(client, query)

        query = DatabaseQuery.new
          |> DatabaseQuery.statement(@insert_devicelog_status_1)
          |> DatabaseQuery.put(:endpoint_id, endpoint_id)
        DatabaseQuery.call!(client, query)

        query = DatabaseQuery.new
          |> DatabaseQuery.statement(@find_devicelog_status_entry)
          |> DatabaseQuery.put(:endpoint_id, endpoint_id)
        entry = DatabaseQuery.call!(client, query)
          |> Enum.to_list

        assert entry == [[device_id: <<83, 107, 226, 73, 170, 170, 78, 2, 149, 131, 90, 72, 51, 203, 254, 73>>, path: "/filterRules/0/testKey/value", endpoint_tokens: ["0", "testKey"], reception_timestamp: 1328241960000, string_value: "T€ST_VÆLÙE"]]

        query = DatabaseQuery.new
          |> DatabaseQuery.statement(@find_devicelog_status_entries)
          |> DatabaseQuery.put(:endpoint_id, endpoint_id)
        entries = DatabaseQuery.call!(client, query)
          |> Enum.to_list

        assert entries == [[path: "/filterRules/0/testKey/value"], [path: "/filterRules/1/testKey2/value"]];

        destroy_local_test_keyspace()

      {:error, msg} -> Logger.warn "Skipped 'individual interface install' test, database engine says: " <> msg
    end
  end

end
