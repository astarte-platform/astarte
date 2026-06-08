#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.DataAccess.Device.XandraTest do
  use ExUnit.Case
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.Device

  setup do
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.seed_data(conn)
    end)
  end

  setup_all do
    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.destroy_local_test_keyspace(conn)
      end)
    end)

    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
    end)

    :ok
  end

  test "retrieve interface version for a certain device" do
    {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

    missing_device_id = :crypto.strong_rand_bytes(16)

    assert Device.interface_version(
             "autotestrealm",
             device_id,
             "com.test.SimpleStreamTest"
           ) == {:ok, 1}

    assert Device.interface_version("autotestrealm", device_id, "com.Missing") ==
             {:error, :interface_not_in_introspection}

    assert Device.interface_version(
             "autotestrealm",
             missing_device_id,
             "com.test.SimpleStreamTest"
           ) ==
             {:error, :device_not_found}

    assert Device.interface_version(
             "autotestrealm",
             missing_device_id,
             "com.Missing"
           ) ==
             {:error, :device_not_found}
  end

  test "error when retrieving interface version on a device that has no introspection" do
    device_id = :crypto.strong_rand_bytes(16)

    insert_empty_introspection_stmt = """
    INSERT INTO autotestrealm.devices (device_id, introspection)
    VALUES (:device_id, :empty_introspection);
    """

    prepared =
      Xandra.Cluster.prepare!(:astarte_data_access_xandra, insert_empty_introspection_stmt)

    Xandra.Cluster.execute!(:astarte_data_access_xandra, prepared, %{
      "device_id" => device_id,
      "empty_introspection" => %{}
    })

    assert Device.interface_version(
             "autotestrealm",
             device_id,
             "com.test.SimpleStreamTest"
           ) == {:error, :interface_not_in_introspection}
  end

  describe "fetch/2" do
    test "returns an existing device" do
      {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

      assert {:ok, device} = Device.fetch("autotestrealm", device_id)
      assert device.device_id == device_id
    end

    test "returns error for a missing device" do
      missing_id = :crypto.strong_rand_bytes(16)

      assert {:error, :device_not_found} = Device.fetch("autotestrealm", missing_id)
    end
  end

  describe "register/5" do
    test "registers a new device" do
      new_device_id = :crypto.strong_rand_bytes(16)
      credentials_secret = "test_secret_#{System.unique_integer()}"

      assert {:ok, _device} =
               Device.register(
                 "autotestrealm",
                 new_device_id,
                 "base64encodedid",
                 credentials_secret
               )
    end

    test "returns error when registering an already-confirmed device" do
      {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

      assert {:error, :device_already_registered} =
               Device.register(
                 "autotestrealm",
                 device_id,
                 "f0VMRgIBAQAAAAAAAAAAAA",
                 "some_secret"
               )
    end

    test "re-registers an existing unconfirmed device" do
      device_id = :crypto.strong_rand_bytes(16)

      assert {:ok, _} = Device.register("autotestrealm", device_id, "extid", "secret_v1")

      assert {:ok, device} =
               Device.register("autotestrealm", device_id, "extid", "secret_v2")

      assert device.credentials_secret == "secret_v2"
    end

    test "re-registers an unconfirmed device with unconfirmed: true sets a TTL" do
      device_id = :crypto.strong_rand_bytes(16)

      assert {:ok, _} = Device.register("autotestrealm", device_id, "extid", "secret_v1")

      assert {:ok, device} =
               Device.register("autotestrealm", device_id, "extid", "secret_v2",
                 unconfirmed: true
               )

      assert device.credentials_secret == "secret_v2"
    end

    test "re-registers an unconfirmed device with initial_introspection" do
      device_id = :crypto.strong_rand_bytes(16)

      assert {:ok, _} = Device.register("autotestrealm", device_id, "extid", "secret_v1")

      introspection = [
        %{interface_name: "com.example.Foo", major_version: 1, minor_version: 2}
      ]

      assert {:ok, device} =
               Device.register("autotestrealm", device_id, "extid", "secret_v2",
                 initial_introspection: introspection
               )

      assert device.introspection == [{"com.example.Foo", 1}]
      assert device.introspection_minor == [{"com.example.Foo", 2}]
    end
  end
end
