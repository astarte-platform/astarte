#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.DataAccess.DeviceTest do
  use ExUnit.Case
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Device

  setup do
    DatabaseTestHelper.seed_data()
  end

  setup_all do
    {:ok, _client} = DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    :ok
  end

  test "retrieve interface version for a certain device" do
    {:ok, db_client} = Database.connect(realm: "autotestrealm")

    {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")
    assert Device.interface_version(db_client, device_id, "com.test.SimpleStreamTest") == {:ok, 1}

    assert Device.interface_version(db_client, device_id, "com.Missing") ==
             {:error, :interface_not_in_introspection}

    missing_device_id = :crypto.strong_rand_bytes(16)

    assert Device.interface_version(db_client, missing_device_id, "com.test.SimpleStreamTest") ==
             {:error, :device_not_found}

    assert Device.interface_version(db_client, missing_device_id, "com.Missing") ==
             {:error, :device_not_found}
  end
end
