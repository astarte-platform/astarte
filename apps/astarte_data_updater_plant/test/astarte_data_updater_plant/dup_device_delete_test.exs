#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DeviceDeleteTest do
  use ExUnit.Case
  import Ecto.Query
  import Mox

  alias Astarte.Core.Device
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Devices.Device, as: DeviceSchema
  alias Astarte.DataAccess.Repo
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.DataUpdaterPlant.DataUpdater

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    realm = "autotestrealm#{System.unique_integer([:positive])}"
    DatabaseTestHelper.destroy_local_test_keyspace(realm)
    {:ok, _keyspace_name} = DatabaseTestHelper.create_test_keyspace(realm)

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace(realm)
    end)

    %{realm: realm}
  end

  test "device deletion is acked and related DataUpdater process stops", %{realm: realm} do
    AMQPTestHelper.clean_queue()

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    # Register the device with some fake data
    total_received_messages = 42
    total_received_bytes = 4242

    insert_opts = [
      total_received_msgs: total_received_messages,
      total_received_bytes: total_received_bytes
    ]

    DatabaseTestHelper.insert_device(realm, device_id, insert_opts)

    keyspace_name = Realm.keyspace_name(realm)

    %DeletionInProgress{device_id: device_id}
    |> Repo.insert(prefix: keyspace_name)

    timestamp_us_x_10 = make_timestamp("2017-10-09T15:00:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    Astarte.DataUpdaterPlant.RPC.VMQPlugin.ClientMock
    |> expect(:delete, fn %{realm_name: ^realm, device_id: ^encoded_device_id} ->
      :ok
    end)

    DataUpdater.start_device_deletion(realm, encoded_device_id, timestamp_ms)

    # Check DUP start ack in deleted_devices table
    dup_start_ack_query =
      from d in DeletionInProgress,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        select: d.dup_start_ack

    dup_start_ack_result = Repo.all(dup_start_ack_query)

    assert [true] = dup_start_ack_result

    # Check that no data is being handled
    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "this.interface.does.not.Exist",
      "/don/t/care",
      :dontcare,
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:30:15+00:00")
    )

    received_data_query =
      from d in DeviceSchema,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        select: %{
          "total_received_msgs" => d.total_received_msgs,
          "total_received_bytes" => d.total_received_bytes
        }

    {:ok, received_data_result} = Repo.fetch_all(received_data_query)

    assert [
             %{
               "total_received_msgs" => ^total_received_messages,
               "total_received_bytes" => ^total_received_bytes
             }
           ] = received_data_result

    # Now process the device's last message
    DataUpdater.handle_internal(
      realm,
      encoded_device_id,
      "/f",
      :dontcare,
      gen_tracking_id(),
      timestamp_us_x_10
    )

    # Let the process handle device's last message
    Process.sleep(100)

    # Check DUP end ack in deleted_devices table
    dup_end_ack_query =
      from d in DeletionInProgress,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        select: d.dup_end_ack

    dup_end_ack_result = Repo.all(dup_end_ack_query)

    assert [true] = dup_end_ack_result

    # Finally, check that the related DataUpdater process exists no more
    assert [] = Horde.Registry.lookup(Registry.DataUpdater, {realm, device_id})
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
