#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
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
    {:ok, db_client} = Database.connect("autotestrealm")

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
