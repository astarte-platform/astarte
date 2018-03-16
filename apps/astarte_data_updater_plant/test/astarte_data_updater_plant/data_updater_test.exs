defmodule Astarte.DataUpdaterPlant.DataUpdaterTest do
  use ExUnit.Case
  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.Core.CQLUtils
  alias CQEx.Client, as: DatabaseClient
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult

  setup_all do
    {:ok, _client} = Astarte.DataUpdaterPlant.DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      Astarte.DataUpdaterPlant.DatabaseTestHelper.destroy_local_test_keyspace()
    end)
  end

  test "simple flow" do
    realm = "autotestrealm"
    device_id = "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ"
    device_id_uuid = DatabaseTestHelper.extended_id_to_uuid(device_id)

    received_msgs = 45000
    received_bytes = 4_500_000
    existing_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}
    existing_introspection_string = "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0"

    insert_opts = [
      introspection: existing_introspection_map,
      total_received_msgs: received_msgs,
      total_received_bytes: received_bytes
    ]

    DatabaseTestHelper.insert_device(device_id, insert_opts)

    db_client = connect_to_db(realm)

    DataUpdater.handle_connection(
      realm,
      device_id,
      "10.0.0.1",
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT connected, total_received_msgs, total_received_bytes FROM devices WHERE device_id=:device_id;"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)

    device_row =
      DatabaseQuery.call!(db_client, device_query)
      |> DatabaseResult.head()

    assert device_row == [
             connected: true,
             total_received_msgs: 45000,
             total_received_bytes: 4_500_000
           ]

    # Introspection sub-test
    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id;")
      |> DatabaseQuery.put(:device_id, device_id_uuid)

    ^existing_introspection_map =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)
      |> Enum.into(%{})

    DataUpdater.handle_introspection(
      realm,
      device_id,
      existing_introspection_string,
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    device_introspection =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)
      |> Enum.into(%{})

    assert existing_introspection_map == device_introspection

    # Incoming data sub-test
    DataUpdater.handle_data(
      realm,
      device_id,
      "com.test.LCDMonitor",
      "/time/from",
      Bson.encode(%{"v" => 9000}),
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:10:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/9/start",
      Bson.encode(%{"v" => 9}),
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:10:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/10/start",
      Bson.encode(%{"v" => 10}),
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:10:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.test.SimpleStreamTest",
      "/0/value",
      Bson.encode(%{"v" => 5}),
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:15:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/time/from")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.LCDMonitor", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/time/from")

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [longinteger_value: 9000]

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.SimpleStreamTest", 1, "/0/value")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT integer_value FROM individual_datastream WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path AND value_timestamp>=:value_timestamp"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.SimpleStreamTest", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/0/value")
      |> DatabaseQuery.put(:value_timestamp, 1_507_557_632_000)

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [integer_value: 5]

    # Introspection change subtest
    DataUpdater.handle_introspection(
      realm,
      device_id,
      "com.test.LCDMonitor:1:0;com.example.TestObject:1:5;com.test.SimpleStreamTest:1:0",
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    # Incoming object aggregation subtest
    payload0 = Bson.encode(%{"value" => 1.9, "string" => "Astarteです"})

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.example.TestObject",
      "/",
      payload0,
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-26T08:48:49+00:00"), 1), :milliseconds) *
        10000
    )

    payload1 = Bson.encode(%{"string" => "Hello World');"})

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.example.TestObject",
      "/",
      payload1,
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-26T08:48:50+00:00"), 1), :milliseconds) *
        10000
    )

    payload2 = Bson.encode(%{"v" => %{"value" => 0}})

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.example.TestObject",
      "/",
      payload2,
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-26T08:48:51+00:00"), 1), :milliseconds) *
        10000
    )

    # we expect only /string to be updated here, we need this to check against accidental NULL insertions, that are bad for tombstones on cassandra.
    payload3 = Bson.encode(%{"string" => "zzz"})

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.example.TestObject",
      "/",
      payload3,
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-09-30T07:13:00+00:00"), 1), :milliseconds) *
        10000
    )

    payload4 = Bson.encode(%{})

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.example.TestObject",
      "/",
      payload4,
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-30T07:13:00+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    objects_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT * FROM com_example_testobject_v1 WHERE device_id=:device_id"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)

    objects =
      DatabaseQuery.call!(db_client, objects_query)
      |> Enum.to_list()

    assert objects == [
             [
               device_id: device_id_uuid,
               reception_timestamp: 1_506_755_400_000,
               reception_timestamp_submillis: 0,
               string: "aaa",
               value: 1.1
             ],
             [
               device_id: device_id_uuid,
               reception_timestamp: 1_506_755_520_000,
               reception_timestamp_submillis: 0,
               string: "bbb",
               value: 2.2
             ],
             [
               device_id: device_id_uuid,
               reception_timestamp: 1_506_755_580_000,
               reception_timestamp_submillis: 0,
               string: "zzz",
               value: 3.3
             ],
             [
               device_id: device_id_uuid,
               reception_timestamp: 1_509_007_729_000,
               reception_timestamp_submillis: 0,
               string: "Astarteです",
               value: 1.9
             ],
             [
               device_id: device_id_uuid,
               reception_timestamp: 1_509_007_730_000,
               reception_timestamp_submillis: 0,
               string: "Hello World');",
               value: nil
             ],
             [
               device_id: device_id_uuid,
               reception_timestamp: 1_509_007_731_000,
               reception_timestamp_submillis: 0,
               string: nil,
               value: 0.0
             ],
             [
               device_id: device_id_uuid,
               reception_timestamp: 1_509_347_580_000,
               reception_timestamp_submillis: 0,
               string: nil,
               value: nil
             ]
           ]

    # Test /producer/properties control message
    data =
      <<0, 0, 0, 98>> <>
        :zlib.compress("com.test.LCDMonitor/time/to;com.test.LCDMonitor/weekSchedule/10/start")

    DataUpdater.handle_control(
      realm,
      device_id,
      "/producer/properties",
      data,
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/time/from")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.LCDMonitor", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/time/from")

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == :empty_dataset

    endpoint_id =
      retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/weekSchedule/9/start")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.LCDMonitor", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/weekSchedule/9/start")

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == :empty_dataset

    endpoint_id =
      retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/weekSchedule/10/start")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.LCDMonitor", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/weekSchedule/10/start")

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [longinteger_value: 10]

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.SimpleStreamTest", 1, "/0/value")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT integer_value FROM individual_datastream WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path AND value_timestamp>=:value_timestamp"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.SimpleStreamTest", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/0/value")
      |> DatabaseQuery.put(:value_timestamp, 1_507_557_632_000)

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [integer_value: 5]

    # Unset subtest
    DataUpdater.handle_data(
      realm,
      device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/10/start",
      <<>>,
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T15:10:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    endpoint_id =
      retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/weekSchedule/10/start")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.LCDMonitor", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/weekSchedule/10/start")

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == :empty_dataset

    # Device disconnection sub-test
    DataUpdater.handle_disconnection(
      realm,
      device_id,
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:30:45+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    device_row =
      DatabaseQuery.call!(db_client, device_query)
      |> DatabaseResult.head()

    assert device_row == [
             connected: false,
             total_received_msgs: 45013,
             total_received_bytes: 4_500_692
           ]
  end

  test "empty introspection is updated correctly" do
    realm = "autotestrealm"

    device_id =
      :crypto.strong_rand_bytes(32)
      |> Base.url_encode64(padding: false)

    device_id_uuid = DatabaseTestHelper.extended_id_to_uuid(device_id)
    new_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}
    new_introspection_string = "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0"

    DatabaseTestHelper.insert_device(device_id)

    db_client = connect_to_db(realm)

    DataUpdater.handle_connection(
      realm,
      device_id,
      "10.0.0.1",
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-12-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id;")
      |> DatabaseQuery.put(:device_id, device_id_uuid)

    old_device_introspection =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)

    assert old_device_introspection == :null

    DataUpdater.handle_introspection(
      realm,
      device_id,
      new_introspection_string,
      nil,
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    new_device_introspection =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)
      |> Enum.into(%{})

    assert new_device_introspection == new_introspection_map
  end

  defp retrieve_endpoint_id(client, interface_name, interface_major, path) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT * FROM interfaces WHERE name = :name AND major_version = :major_version;"
      )
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

  defp connect_to_db(realm) do
    DatabaseClient.new!(
      List.first(Application.get_env(:cqerl, :cassandra_nodes)),
      keyspace: realm
    )
  end
end
