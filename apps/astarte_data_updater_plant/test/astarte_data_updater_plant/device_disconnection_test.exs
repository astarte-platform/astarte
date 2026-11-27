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
  alias Astarte.DataAccess.Device, as: DeviceSchema
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.Helpers.DataUpdater

  alias Astarte.Secrets
  alias COSE.Keys.Symmetric

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

    {:ok, _} = Secrets.create_realm_kek(realm_string)

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

  describe "device clean session disconnection" do
    setup %{realm: realm} do
      device_id = Device.random_device_id()
      encoded_device_id = Device.encode_device_id(device_id)

      DatabaseTestHelper.insert_device(realm, device_id, introspection: %{})

      key = :crypto.strong_rand_bytes(32)
      shared_secret_in_state = %Symmetric{k: key, alg: :aes_256_gcm}

      {:ok, encrypted_key} = Secrets.encrypt_with_kek(realm, key)
      shared_secret_in_db = %Symmetric{k: encrypted_key, alg: :aes_256_gcm}

      :ok = Queries.save_shared_secret(realm, device_id, shared_secret_in_db)

      %{
        device_id: device_id,
        encoded_device_id: encoded_device_id,
        key: key,
        shared_secret_in_state: shared_secret_in_state
      }
    end

    test "with header x_astarte_clean_mqtt_session = true clears the shared secret",
         %{
           realm: realm,
           device_id: device_id,
           encoded_device_id: encoded_device_id
         } do
      timestamp = make_timestamp("2026-11-27T14:30:45+00:00")

      DataUpdater.handle_disconnection(realm, encoded_device_id, timestamp, true)

      state = DataUpdater.dump_state(realm, encoded_device_id)

      assert state.connected == false
      assert state.shared_secret == nil
      assert state.encrypted_endpoints_key == :uninitialized

      assert %{shared_secret: nil, encrypted_endpoints_key: :uninitialized} =
               Queries.get_device_status(realm, device_id)
    end

    test "with header x_astarte_clean_mqtt_session = false preserves the shared secret",
         %{
           realm: realm,
           device_id: device_id,
           encoded_device_id: encoded_device_id,
           key: key,
           shared_secret_in_state: shared_secret
         } do
      timestamp = make_timestamp("2026-11-27T14:30:45+00:00")

      DataUpdater.handle_disconnection(realm, encoded_device_id, timestamp, false)

      state = DataUpdater.dump_state(realm, encoded_device_id)

      assert state.connected == false
      assert state.shared_secret == shared_secret
      assert state.encrypted_endpoints_key == {:established, %{shared_secret: key}}

      assert %{
               shared_secret: ^shared_secret,
               encrypted_endpoints_key: {:established, %{shared_secret: ^key}}
             } = Queries.get_device_status(realm, device_id)
    end
  end

  defp make_timestamp(timestamp_string) do
    {:ok, date_time, _} = DateTime.from_iso8601(timestamp_string)

    DateTime.to_unix(date_time, :millisecond) * 10_000
  end
end
