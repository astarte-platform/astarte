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

defmodule Astate.DataUpdaterPlant.UnsetTest do
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
  alias Astarte.DataUpdaterPlant.DatabaseTestHelper

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

  test "Unset values from interface properties", %{
    realm: realm,
    helper_name: helper_name
  } do
    AMQPTestHelper.clean_queue(helper_name)

    encoded_device_id = "f0VMRgIBAQAAAAAAAAAAAA"
    keyspace_name = Realm.keyspace_name(realm)
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)
    volatile_changed_trigger_id = :crypto.strong_rand_bytes(16)

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

    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             encoded_device_id,
             volatile_changed_trigger_id
           ) == :ok

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/10/start",
      <<>>,
      gen_tracking_id(),
      make_timestamp("2017-10-09T15:10:32+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)

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

    assert value == nil
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

  defp make_timestamp(timestamp_string) do
    {:ok, date_time, _} = DateTime.from_iso8601(timestamp_string)

    DateTime.to_unix(date_time, :millisecond) * 10000
  end

  defp gen_tracking_id() do
    message_id = :erlang.unique_integer([:monotonic]) |> Integer.to_string()
    delivery_tag = {:injected_msg, make_ref()}
    {message_id, delivery_tag}
  end
end
