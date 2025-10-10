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

defmodule Astarte.DataUpdaterPlant.ProducerPropertiesTest do
  use ExUnit.Case, async: true
  import Mox

  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.Core.Triggers.SimpleEvents.PathRemovedEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Device
  alias Astarte.DataAccess.Realms.IndividualDatastream

  alias Astarte.Core.CQLUtils

  import Ecto.Query

  setup :verify_on_exit!

  setup do
    realm_string = "autotestrealm#{System.unique_integer([:positive])}"
    {:ok, _keyspace_name} = DatabaseTestHelper.create_test_keyspace(realm_string)

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace(realm_string)
    end)

    helper_name = String.to_atom("helper_#{realm_string}")

    consumer_name = String.to_atom("consumer_#{realm_string}")

    {:ok, _pid} = AMQPTestHelper.start_link(name: helper_name, realm: realm_string)

    {:ok, _consumer_pid} =
      AMQPTestHelper.start_events_consumer(
        name: consumer_name,
        realm: realm_string,
        helper_name: helper_name
      )

    {:ok, %{realm: realm_string, helper_name: helper_name}}
  end

  test "producer properties are correctly set", %{
    realm: realm,
    helper_name: helper_name
  } do
    AMQPTestHelper.clean_queue(helper_name)

    keyspace_name = Realm.keyspace_name(realm)
    encoded_device_id = "f0VMRgIBAQAAAAAAAAAAAA"
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    received_msgs = 45000
    received_bytes = 4_500_000
    existing_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}

    insert_opts = [
      introspection: existing_introspection_map,
      total_received_msgs: received_msgs,
      total_received_bytes: received_bytes,
      groups: ["group1"]
    ]

    DatabaseTestHelper.insert_device(realm, device_id, insert_opts)

    data =
      <<0, 0, 0, 98>> <>
        :zlib.compress("com.test.LCDMonitor/time/to;com.test.LCDMonitor/weekSchedule/10/start")

    timestamp_us_x_10 = make_timestamp("2017-10-09T14:00:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    DataUpdater.handle_control(
      realm,
      encoded_device_id,
      "/producer/properties",
      data,
      gen_tracking_id(),
      timestamp_us_x_10
    )

    datastream_timestamp = make_timestamp("2017-10-09T14:15:32+00:00")

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.test.SimpleStreamTest",
      "/0/value",
      Cyanide.encode!(%{"v" => 5}),
      gen_tracking_id(),
      datastream_timestamp
    )

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/10/start",
      Cyanide.encode!(%{"v" => 10}),
      gen_tracking_id(),
      datastream_timestamp
    )

    DataUpdater.dump_state(realm, encoded_device_id)
    {remove_event, remove_headers, _meta} = AMQPTestHelper.wait_and_get_message(helper_name)

    assert remove_headers["x_astarte_event_type"] == "path_removed_event"
    assert remove_headers["x_astarte_device_id"] == encoded_device_id
    assert remove_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(remove_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(remove_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.path_removed_trigger_id()

    assert SimpleEvent.decode(remove_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event:
               {:path_removed_event,
                %PathRemovedEvent{interface: "com.test.LCDMonitor", path: "/time/from"}},
             timestamp: timestamp_ms,
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.path_removed_trigger_id()
           }

    endpoint_id = retrieve_endpoint_id(realm, "com.test.LCDMonitor", 1, "/time/from")

    value_query =
      from ip in IndividualProperty,
        prefix: ^keyspace_name,
        where:
          ip.device_id == ^device_id and
            ip.interface_id == ^CQLUtils.interface_id("com.test.LCDMonitor", 1) and
            ip.endpoint_id == ^endpoint_id and
            ip.path == "/time/from",
        select: ip.longinteger_value

    value = Repo.one(value_query)

    assert value == nil

    endpoint_id =
      retrieve_endpoint_id(realm, "com.test.LCDMonitor", 1, "/weekSchedule/9/start")

    value_query =
      from ip in IndividualProperty,
        prefix: ^keyspace_name,
        where:
          ip.device_id == ^device_id and
            ip.interface_id == ^CQLUtils.interface_id("com.test.LCDMonitor", 1) and
            ip.endpoint_id == ^endpoint_id and
            ip.path == "/weekSchedule/9/start",
        select: ip.longinteger_value

    value = Repo.one(value_query)

    assert value == nil

    endpoint_id =
      retrieve_endpoint_id(realm, "com.test.LCDMonitor", 1, "/weekSchedule/10/start")

    value_query =
      from ip in IndividualProperty,
        prefix: ^keyspace_name,
        where:
          ip.device_id == ^device_id and
            ip.interface_id == ^CQLUtils.interface_id("com.test.LCDMonitor", 1) and
            ip.endpoint_id == ^endpoint_id and
            ip.path == "/weekSchedule/10/start",
        select: ip.longinteger_value

    value = Repo.one(value_query)

    assert value == 10

    endpoint_id = retrieve_endpoint_id(realm, "com.test.SimpleStreamTest", 1, "/0/value")

    timestamp_ms = DateTime.from_unix!(1_507_557_632_000, :millisecond)

    value_query =
      from id in IndividualDatastream,
        prefix: ^keyspace_name,
        where:
          id.device_id == ^device_id and
            id.interface_id == ^CQLUtils.interface_id("com.test.SimpleStreamTest", 1) and
            id.endpoint_id == ^endpoint_id and
            id.path == "/0/value" and
            id.value_timestamp >= ^timestamp_ms,
        select: id.integer_value

    value = Repo.one(value_query)

    assert value == 5
  end

  defp retrieve_endpoint_id(realm_name, interface_name, interface_major, path) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from i in Interface,
        prefix: ^keyspace_name,
        where: i.name == ^interface_name and i.major_version == ^interface_major,
        select: %{
          automaton_transitions: i.automaton_transitions,
          automaton_accepting_states: i.automaton_accepting_states
        }

    interface_row = Repo.one!(query)

    automaton =
      {:erlang.binary_to_term(interface_row[:automaton_transitions]),
       :erlang.binary_to_term(interface_row[:automaton_accepting_states])}

    {:ok, endpoint_id} = Astarte.Core.Mapping.EndpointsAutomaton.resolve_path(path, automaton)

    endpoint_id
  end

  defp gen_tracking_id() do
    message_id = :erlang.unique_integer([:monotonic]) |> Integer.to_string()
    delivery_tag = {:injected_msg, make_ref()}
    {message_id, delivery_tag}
  end

  defp make_timestamp(timestamp_string) do
    {:ok, date_time, _} = DateTime.from_iso8601(timestamp_string)

    DateTime.to_unix(date_time, :millisecond) * 10000
  end
end
