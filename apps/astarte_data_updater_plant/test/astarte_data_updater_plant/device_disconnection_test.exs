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

defmodule Astarte.DataUpdaterPlant.DeviceDisconnectionTest do
  use ExUnit.Case, async: true
  import Mox

  alias Astarte.Core.Device
  alias Astarte.DataAccess.Devices.Device, as: DeviceSchema
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.DataUpdaterPlant.DataUpdater

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

  test "device disconnection test", %{realm: realm, helper_name: helper_name} do
    AMQPTestHelper.clean_queue(helper_name)

    keyspace_name = Realm.keyspace_name(realm)
    encoded_device_id = "f0VMRgIBAQAAAAAAAAAAAA"
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    received_msgs = 45_000
    received_bytes = 4_500_000
    existing_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}

    insert_opts = [
      introspection: existing_introspection_map,
      total_received_msgs: received_msgs,
      total_received_bytes: received_bytes,
      groups: ["group1"]
    ]

    DatabaseTestHelper.insert_device(realm, device_id, insert_opts)

    DataUpdater.handle_disconnection(
      realm,
      encoded_device_id,
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:30:45+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)

    device_query =
      from d in DeviceSchema,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        select: %{
          connected: d.connected,
          total_received_msgs: d.total_received_msgs,
          total_received_bytes: d.total_received_bytes,
          exchanged_msgs_by_interface: d.exchanged_msgs_by_interface,
          exchanged_bytes_by_interface: d.exchanged_bytes_by_interface
        }

    device_row = Repo.one(device_query)

    assert device_row == %{
             connected: false,
             total_received_msgs: received_msgs,
             total_received_bytes: received_bytes,
             exchanged_msgs_by_interface: %{},
             exchanged_bytes_by_interface: %{}
           }

    assert AMQPTestHelper.awaiting_messages_count(helper_name) == 0
  end

  defp gen_tracking_id do
    message_id = :erlang.unique_integer([:monotonic]) |> Integer.to_string()
    delivery_tag = {:injected_msg, make_ref()}
    {message_id, delivery_tag}
  end

  defp make_timestamp(timestamp_string) do
    {:ok, date_time, _} = DateTime.from_iso8601(timestamp_string)

    DateTime.to_unix(date_time, :millisecond) * 10_000
  end
end
