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
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.AMQP

  import Mox
  import Astarte.Helpers.DataUpdater

  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Devices.Device, as: DeviceSchema
  alias Astarte.DataUpdaterPlant.AMQPTestHelper

  import Ecto.Query

  setup :verify_on_exit!

  setup_all %{realm_name: realm_name} do
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

    DatabaseTestHelper.insert_device(realm_name, device_id, insert_opts)
    setup_data_updater(realm_name, encoded_device_id)

    %{
      device_id: device_id,
      encoded_device_id: encoded_device_id,
      received_msgs: received_msgs,
      received_bytes: received_bytes
    }
  end

  test "device disconnection test", context do
    %{
      realm: realm,
      amqp_consumer: amqp_consumer,
      device_id: device_id,
      encoded_device_id: encoded_device_id,
      received_msgs: received_msgs,
      received_bytes: received_bytes
    } = context

    keyspace_name = Realm.keyspace_name(realm)

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

    assert AMQPTestHelper.awaiting_messages_count(amqp_consumer) == 0
  end
end
