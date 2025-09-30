defmodule Astarte.DataUpdaterPlant.DeviceDeletionTest do
  use ExUnit.Case, async: true
  import Mox

  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Devices.Device, as: DeviceSchema
  alias Astarte.DataUpdaterPlant.AMQPTestHelper

  import Ecto.Query

  setup :verify_on_exit!

  setup do
    realm = "autotestrealm#{System.unique_integer([:positive])}"
    {:ok, _keyspace_name} = DatabaseTestHelper.create_test_keyspace(realm)

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace(realm)
    end)

    {:ok, _pid} = AMQPTestHelper.start_link()
    %{realm: realm}
  end

  test "device deletion test", %{realm: realm} do
    # common setup block
    AMQPTestHelper.clean_queue()

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
    ### -----------------------------------------------------------####################

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
    IO.inspect(device_query, label: "Device query")
    IO.inspect(device_row, label: "Device row after disconnection")

    assert device_row == %{
             connected: false,
             total_received_msgs: 45000,
             total_received_bytes: 4_500_000,
             exchanged_msgs_by_interface: %{},
             exchanged_bytes_by_interface: %{}
           }

    assert AMQPTestHelper.awaiting_messages_count() == 0
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
