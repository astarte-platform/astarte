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
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.AMQP

  import Mox
  import Astarte.Helpers.DataUpdater

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

  setup_all %{realm_name: realm_name} do
    device_id = Device.random_device_id()
    encoded_device_id = Device.encode_device_id(device_id)
    received_msgs = 45000
    received_bytes = 4_500_000
    existing_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}

    insert_opts = [
      introspection: existing_introspection_map,
      total_received_msgs: received_msgs,
      total_received_bytes: received_bytes,
      groups: ["group1"]
    ]

    DatabaseTestHelper.insert_device(realm_name, device_id, insert_opts)
    test_process = self()

    Astarte.DataUpdaterPlant.RPC.VMQPlugin.ClientMock
    |> Mox.stub(:delete, fn %{realm_name: ^realm_name, device_id: ^encoded_device_id} ->
      send(test_process, :unset_properties_message_received)
      :ok
    end)

    setup_data_updater(realm_name, encoded_device_id)

    %{
      device_id: device_id,
      encoded_device_id: encoded_device_id,
      received_msgs: received_msgs,
      received_bytes: received_bytes
    }
  end

  test "Unset values from interface properties", %{
    realm: realm,
    amqp_consumer: amqp_consumer,
    device_id: device_id,
    encoded_device_id: encoded_device_id
  } do
    AMQPTestHelper.clean_queue(amqp_consumer)

    keyspace_name = Realm.keyspace_name(realm)
    volatile_changed_trigger_id = :crypto.strong_rand_bytes(16)

    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             encoded_device_id,
             volatile_changed_trigger_id
           ) == :ok

    # DataUpdater.handle_data(
    #   realm,
    #   encoded_device_id,
    #   "com.test.LCDMonitor",
    #   "/weekSchedule/10/start",
    #   <<>>,
    #   gen_tracking_id(),
    #   make_timestamp("2017-10-09T15:10:32+00:00")
    # )

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
end
