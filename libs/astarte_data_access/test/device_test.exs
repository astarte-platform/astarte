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
  use Astarte.DataAccess.Cases.Database, async: true
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.DataAccess.Device
  alias Astarte.DataAccess.Device.UnconfirmedDevice
  alias Astarte.DataAccess.Devices.Device, as: DeviceStruct
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  setup :seed_data

  test "retrieve interface version for a certain device", context do
    %{realm_name: realm_name} = context
    {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

    missing_device_id = :crypto.strong_rand_bytes(16)

    assert Device.interface_version(
             realm_name,
             device_id,
             "com.test.SimpleStreamTest"
           ) == {:ok, 1}

    assert Device.interface_version(realm_name, device_id, "com.Missing") ==
             {:error, :interface_not_in_introspection}

    assert Device.interface_version(
             realm_name,
             missing_device_id,
             "com.test.SimpleStreamTest"
           ) ==
             {:error, :device_not_found}

    assert Device.interface_version(
             realm_name,
             missing_device_id,
             "com.Missing"
           ) ==
             {:error, :device_not_found}
  end

  test "error when retrieving interface version on a device that has no introspection", context do
    %{realm_name: realm_name} = context
    device_id = :crypto.strong_rand_bytes(16)

    %DeviceStruct{device_id: device_id, introspection: %{}}
    |> Repo.insert!(prefix: Realm.keyspace_name(realm_name))

    assert Device.interface_version(
             realm_name,
             device_id,
             "com.test.SimpleStreamTest"
           ) == {:error, :interface_not_in_introspection}
  end

  describe "fetch/2" do
    test "returns an existing device", context do
      %{realm_name: realm_name} = context
      {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

      assert {:ok, device} = Device.fetch(realm_name, device_id)
      assert device.device_id == device_id
    end

    test "returns error for a missing device", context do
      %{realm_name: realm_name} = context
      missing_id = :crypto.strong_rand_bytes(16)

      assert {:error, :device_not_found} = Device.fetch(realm_name, missing_id)
    end
  end

  describe "register/5" do
    test "registers a new device", context do
      %{realm_name: realm_name} = context
      new_device_id = :crypto.strong_rand_bytes(16)
      credentials_secret = "test_secret_#{System.unique_integer()}"

      assert {:ok, _device} =
               Device.register(
                 realm_name,
                 new_device_id,
                 "base64encodedid",
                 credentials_secret
               )
    end

    test "returns error when registering an already-confirmed device", context do
      %{realm_name: realm_name} = context
      {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

      assert {:error, :device_already_registered} =
               Device.register(
                 realm_name,
                 device_id,
                 "f0VMRgIBAQAAAAAAAAAAAA",
                 "some_secret"
               )
    end

    test "re-registers an existing unconfirmed device", context do
      %{realm_name: realm_name} = context
      device_id = :crypto.strong_rand_bytes(16)

      assert {:ok, _} = Device.register(realm_name, device_id, "extid", "secret_v1")

      assert {:ok, device} =
               Device.register(realm_name, device_id, "extid", "secret_v2")

      assert device.credentials_secret == "secret_v2"
    end

    test "with unconfirmed: true creates `Astarte.DataAccess.Device.UnconfirmedDevice` entry",
         context do
      %{realm_name: realm_name} = context
      device_id = CoreDevice.random_device_id()

      assert {:ok, _} = Device.register(realm_name, device_id, "extid", "secret_v1")

      assert {:ok, device} =
               Device.register(realm_name, device_id, "extid", "secret_v2", unconfirmed: true)

      assert device.credentials_secret == "secret_v2"

      assert {:ok, %UnconfirmedDevice{device_id: ^device_id}} =
               Repo.fetch(UnconfirmedDevice, device_id, prefix: Realm.keyspace_name(realm_name))
    end

    test "re-registers an unconfirmed device with initial_introspection", context do
      %{realm_name: realm_name} = context
      device_id = :crypto.strong_rand_bytes(16)

      assert {:ok, _} = Device.register(realm_name, device_id, "extid", "secret_v1")

      introspection = [
        %{interface_name: "com.example.Foo", major_version: 1, minor_version: 2}
      ]

      assert {:ok, device} =
               Device.register(realm_name, device_id, "extid", "secret_v2",
                 initial_introspection: introspection
               )

      assert device.introspection == [{"com.example.Foo", 1}]
      assert device.introspection_minor == [{"com.example.Foo", 2}]
    end
  end

  describe "confirm/2" do
    setup :add_unconfirmed_device

    test "confirms an unconfirmed device", context do
      %{device_id: device_id, realm_name: realm_name} = context
      assert {:ok, _} = Device.confirm(realm_name, device_id)
      refute Repo.get(UnconfirmedDevice, device_id, prefix: Realm.keyspace_name(realm_name))
    end

    test "does nothing for confirmed devices", context do
      %{device_id: device_id, realm_name: realm_name} = context
      {:ok, device} = Device.confirm(realm_name, device_id)
      assert Device.confirm(realm_name, device_id) == {:ok, device}
    end

    test "returns an error when the device does not exist", context do
      %{realm_name: realm_name} = context
      device_id = CoreDevice.random_device_id()
      assert Device.confirm(realm_name, device_id) == {:error, :device_not_found}
    end
  end

  defp add_unconfirmed_device(context) do
    %{realm_name: realm_name} = context
    keyspace = Realm.keyspace_name(realm_name)
    device_id = CoreDevice.random_device_id()
    encoded_device_id = CoreDevice.encode_device_id(device_id)
    credentials_secret = "credentials_secret"
    opts = [unconfirmed: true]

    on_exit(fn ->
      Repo.delete!(%DeviceStruct{device_id: device_id}, prefix: keyspace)
      Repo.delete!(%UnconfirmedDevice{device_id: device_id}, prefix: keyspace)
    end)

    {:ok, _} =
      Device.register(realm_name, device_id, encoded_device_id, credentials_secret, opts)

    %{
      device_id: device_id,
      encoded_device_id: encoded_device_id,
      credentials_secret: credentials_secret
    }
  end
end
