#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagement.DeviceRemoval.DeviceRemoverTest do
  use ExUnit.Case
  require Logger

  alias Astarte.Core.CQLUtils
  alias Astarte.RealmManagement.DeviceRemoval.DeviceRemover
  alias Astarte.RealmManagement.DatabaseTestHelper
  alias Astarte.RealmManagement.Queries

  @realm_name "autotestrealm"
  @device_id <<39, 243, 128, 160, 158, 152, 245, 223, 26, 43, 66, 116, 153, 237, 184, 43>>
  @individual_datastream_interface "com.an.individual.datastream.Interface"
  @object_datastream_interface "com.an.object.datastream.Interface"
  @property_interface "com.a.property.Interface"
  @interface_major 0
  @endpoint "/a/%{endpoint}"
  @path "/a/path"

  setup_all do
    {:ok, client} = DatabaseTestHelper.connect_to_test_database()
    DatabaseTestHelper.create_test_keyspace(client)
    seed_device_data!()

    on_exit(fn ->
      {:ok, client} = DatabaseTestHelper.connect_to_test_database()
      DatabaseTestHelper.drop_test_keyspace(client)
    end)
  end

  test "device data are successfully removed" do
    deletion_prepared =
      Xandra.Cluster.prepare!(
        :xandra,
        """
          INSERT INTO #{@realm_name}.deletion_in_progress (device_id, vmq_ack, dup_start_ack, dup_end_ack)
          VALUES (:device_id, false, false, false)
        """
      )

    params = %{device_id: @device_id}

    Xandra.Cluster.execute!(:xandra, deletion_prepared, params)

    :ok = DeviceRemover.run(%{realm_name: @realm_name, device_id: @device_id})

    object_aggregated_interface_table_name =
      CQLUtils.interface_name_to_table_name(
        @object_datastream_interface,
        @interface_major
      )

    assert [] = Queries.retrieve_individual_datastreams_keys!(@realm_name, @device_id)
    assert [] = Queries.retrieve_individual_properties_keys!(@realm_name, @device_id)

    assert [] =
             Queries.retrieve_object_datastream_keys!(
               @realm_name,
               @device_id,
               object_aggregated_interface_table_name
             )

    assert [] = Queries.retrieve_aliases!(@realm_name, @device_id)
    assert [] = Queries.retrieve_groups_keys!(@realm_name, @device_id)

    assert [] =
             Queries.retrieve_kv_store_entries!(
               @realm_name,
               @device_id |> Astarte.Core.Device.encode_device_id()
             )

    devices_prepared =
      Xandra.Cluster.prepare!(
        :xandra,
        "SELECT * FROM #{@realm_name}.devices WHERE device_id = :device_id"
      )

    assert [] =
             Xandra.Cluster.execute!(:xandra, devices_prepared, %{device_id: @device_id},
               uuid_format: :binary
             )
             |> Enum.to_list()
  end

  defp seed_device_data!() do
    DatabaseTestHelper.seed_individual_datastream_test_data!(
      realm_name: @realm_name,
      device_id: @device_id,
      interface_name: @individual_datastream_interface,
      interface_major: @interface_major,
      endpoint: @endpoint,
      path: @path
    )

    DatabaseTestHelper.seed_individual_properties_test_data!(
      realm_name: @realm_name,
      device_id: @device_id,
      interface_name: @property_interface,
      interface_major: @interface_major,
      endpoint: @endpoint,
      path: @path
    )

    DatabaseTestHelper.add_interface_to_introspection!(
      realm_name: @realm_name,
      device_id: @device_id,
      interface_name: @object_datastream_interface,
      interface_major: @interface_major
    )

    DatabaseTestHelper.create_object_datastream_table!(
      CQLUtils.interface_name_to_table_name(@object_datastream_interface, @interface_major)
    )

    DatabaseTestHelper.seed_interfaces_table_object_test_data!(
      realm_name: @realm_name,
      interface_name: @object_datastream_interface,
      interface_major: @interface_major
    )

    DatabaseTestHelper.seed_object_datastream_test_data!(
      realm_name: @realm_name,
      device_id: @device_id,
      interface_name: @object_datastream_interface,
      interface_major: @interface_major,
      path: @path
    )

    DatabaseTestHelper.seed_aliases_test_data!(
      realm_name: @realm_name,
      device_id: @device_id
    )

    DatabaseTestHelper.seed_groups_test_data!(
      realm_name: @realm_name,
      device_id: @device_id
    )

    DatabaseTestHelper.seed_kv_store_test_data!(
      realm_name: @realm_name,
      group: "devices-by-interface-#{@individual_datastream_interface}-v#{@interface_major}",
      device_id: @device_id |> Astarte.Core.Device.encode_device_id()
    )

    DatabaseTestHelper.seed_kv_store_test_data!(
      realm_name: @realm_name,
      group:
        "devices-with-data-on-interface-#{@individual_datastream_interface}-v#{@interface_major}",
      device_id: @device_id |> Astarte.Core.Device.encode_device_id()
    )

    DatabaseTestHelper.seed_devices_test_data!(realm_name: @realm_name, device_id: @device_id)
  end
end
