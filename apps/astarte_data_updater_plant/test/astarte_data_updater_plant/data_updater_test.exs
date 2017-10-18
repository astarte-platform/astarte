defmodule Astarte.DataUpdaterPlant.DataUpdaterTest do
  use ExUnit.Case
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.Core.CQLUtils
  alias CQEx.Client, as: DatabaseClient
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult

  setup do
    {:ok, _client} = Astarte.DataUpdaterPlant.DatabaseTestHelper.create_test_keyspace()

    on_exit fn ->
      Astarte.DataUpdaterPlant.DatabaseTestHelper.destroy_local_test_keyspace()
    end
  end

  test "simple flow" do
    realm = "autotestrealm"
    device_id = "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ"
    device_id_uuid = <<127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

    db_client = connect_to_db(realm)

    DataUpdater.handle_connection(realm, device_id, '10.0.0.1', nil, DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds))
    DataUpdater.dump_state(realm, device_id)

    device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT connected, total_received_msgs, total_received_bytes FROM devices WHERE device_id=:device_id;")
      |> DatabaseQuery.put(:device_id, device_id_uuid)

    device_row =
      DatabaseQuery.call!(db_client, device_query)
      |> DatabaseResult.head()

    assert device_row == [connected: true, total_received_msgs: 45000, total_received_bytes: 4500000]

    # Introspection sub-test
    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id;")
      |> DatabaseQuery.put(:device_id, device_id_uuid)

    prev_device_introspection =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)
      |> Enum.into(%{})

    DataUpdater.handle_introspection(realm, device_id, "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0", nil, DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds))
    DataUpdater.dump_state(realm, device_id)

    device_introspection =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)
      |> Enum.into(%{})

    assert prev_device_introspection == device_introspection

    # Incoming data sub-test
    DataUpdater.handle_data(realm, device_id, "com.test.LCDMonitor", "/time/from", Bson.encode(%{"v" => 9000}), nil, DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:10:32+00:00"), 1), :milliseconds))
    DataUpdater.handle_data(realm, device_id, "com.test.SimpleStreamTest", "/0/value", Bson.encode(%{"v" => 5}), nil, DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:15:32+00:00"), 1), :milliseconds))

    DataUpdater.dump_state(realm, device_id)

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/time/from")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path")
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
      |> DatabaseQuery.statement("SELECT integer_value FROM individual_datastream WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path AND reception_timestamp>=:reception_timestamp")
      |> DatabaseQuery.put(:device_id, device_id_uuid)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.SimpleStreamTest", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/0/value")
      |> DatabaseQuery.put(:reception_timestamp, 1507557632000)

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [integer_value: 5]

    DataUpdater.handle_disconnection(realm, device_id, nil, DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:30:45+00:00"), 1), :milliseconds))
    DataUpdater.dump_state(realm, device_id)

    device_row =
      DatabaseQuery.call!(db_client, device_query)
      |> DatabaseResult.head()

    assert device_row == [connected: false, total_received_msgs: 45003, total_received_bytes: 4500139]
  end

  defp retrieve_endpoint_id(client, interface_name, interface_major, path) do
    query =
      DatabaseQuery.new
      |> DatabaseQuery.statement("SELECT * FROM interfaces WHERE name = :name AND major_version = :major_version;")
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

  defp connect_to_db(realm) do
    DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm])
  end

end
