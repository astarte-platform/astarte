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
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
    end)

    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.destroy_local_test_keyspace(conn)
      end)
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
end
