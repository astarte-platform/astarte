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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.RealmManagement.API.DeviceRemover.CoreTest do
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.Core.CQLUtils
  alias Astarte.RealmManagement.API.Interfaces
  alias Astarte.RealmManagement.API.CreateDatastreamIndividualMultiInterface
  alias Astarte.RealmManagement.API.DeviceRemoval.Queries
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.RealmManagement.API.DeviceRemoval.Core
  alias Astarte.Core.Interface

  use Astarte.Cases.Data, async: true
  use ExUnitProperties

  import ExUnit.CaptureLog

  describe "Device remover Core" do
    @describetag :device_remover

    property "delete_individual_datastream/2 removes individual datastream data of a valid device",
             %{realm: realm} do
      keyspace = Realm.keyspace_name(realm)

      Ecto.Migrator.run(Repo, [{0, CreateDatastreamIndividualMultiInterface}], :up,
        prefix: keyspace,
        all: true
      )

      check all(
              device_id <- Astarte.Core.Generators.Device.id(),
              individual_datastreams <-
                list_of(
                  Astarte.RealmManagement.API.Generators.IndividualDatastream.individual_datastream(
                    device_id: device_id
                  )
                )
            ) do
        individual_datastreams
        |> Enum.each(&Repo.insert!(&1, prefix: keyspace))

        Core.delete_individual_datastreams!(realm, device_id)

        assert Queries.retrieve_individual_datastreams_keys!(realm, device_id) == []
      end
    end

    property "delete_individual_properties/2 removes individual properties data of a valid device",
             %{realm: realm} do
      keyspace = Realm.keyspace_name(realm)

      check all(
              device_id <- Astarte.Core.Generators.Device.id(),
              individual_properties <-
                list_of(
                  Astarte.RealmManagement.API.Generators.IndividualProperty.individual_property(
                    device_id: device_id
                  )
                )
            ) do
        Enum.each(individual_properties, &Repo.insert!(&1, prefix: keyspace))

        Core.delete_individual_properties!(realm, device_id)

        assert Queries.retrieve_individual_properties_keys!(realm, device_id) == []
      end
    end

    property "delete_object_datastream/2 removes object datastreams of a valid device", %{
      realm: realm
    } do
      check all(
              interface <-
                Astarte.Core.Generators.Interface.interface(
                  type: :datastream,
                  aggregation: :object,
                  explicit_timestamp: true
                ),
              device_id <- Astarte.Core.Generators.Device.id(),
              value_timestamp <- repeatedly(&DateTime.utc_now/0),
              reception_timestamp <- repeatedly(&DateTime.utc_now/0),
              reception_timestamp_submillis <- integer(0..10)
            ) do
        seed_device_interface(
          realm,
          interface,
          device_id,
          value_timestamp,
          reception_timestamp,
          reception_timestamp_submillis
        )

        table_name =
          CQLUtils.interface_name_to_table_name(interface.name, interface.major_version)

        Core.delete_object_datastream!(realm, device_id)

        assert Queries.retrieve_object_datastream_keys!(realm, device_id, table_name) == []

        Core.delete_device!(realm, device_id)
      end
    end

    property "delete_aliases/2 removes all aliases of a valid device", %{
      realm: realm
    } do
      keyspace = Realm.keyspace_name(realm)

      check all(
              device_id <- Astarte.Core.Generators.Device.id(),
              aliases <-
                list_of(Astarte.RealmManagement.API.Generators.Name.name(device_id: device_id))
            ) do
        Enum.each(aliases, &Repo.insert!(&1, prefix: keyspace))

        Core.delete_aliases!(realm, device_id)

        assert Queries.retrieve_aliases!(realm, device_id) == []
      end
    end

    property "delete_groups/2 removes all groups of a valid device", %{
      realm: realm
    } do
      keyspace = Realm.keyspace_name(realm)

      check all(
              device_id <- Astarte.Core.Generators.Device.id(),
              grouped_devices <-
                list_of(
                  Astarte.RealmManagement.API.Generators.GroupedDevice.grouped_devide(
                    device_id: device_id
                  )
                )
            ) do
        Enum.each(grouped_devices, &Repo.insert!(&1, prefix: keyspace))

        Core.delete_groups!(realm, device_id)

        assert Queries.retrieve_groups_keys!(realm, device_id) == []
      end
    end

    property "delete_kv_store_entries/2 removes all KvStore entries for a valid device", %{
      realm: realm
    } do
      keyspace = Realm.keyspace_name(realm)

      check all(encoded_device_id <- Astarte.Core.Generators.Device.encoded_id()) do
        %{
          group: "example_group",
          key: encoded_device_id,
          value: "example value"
        }
        |> KvStore.insert(prefix: keyspace)

        Core.delete_kv_store_entries!(realm, encoded_device_id)

        assert Queries.retrieve_kv_store_entries!(realm, encoded_device_id) == []
      end
    end

    property "delete_device/2 removes a device", %{
      realm: realm
    } do
      keyspace = Realm.keyspace_name(realm)

      check all(device_id <- Astarte.Core.Generators.Device.id()) do
        %Device{
          device_id: device_id
        }
        |> Repo.insert!(prefix: keyspace)

        %DeletionInProgress{
          device_id: device_id
        }
        |> Repo.insert!(prefix: keyspace)

        Core.delete_device!(realm, device_id)

        assert Repo.all(Device, prefix: keyspace) == []
        assert Queries.retrieve_devices_to_delete!(realm) == []
      end
    end
  end

  defp seed_device_interface(
         realm,
         interface,
         device_id,
         value_timestamp,
         reception_timestamp,
         reception_timestamp_submillis
       ) do
    keyspace = Realm.keyspace_name(realm)
    interface_json = Jason.encode!(interface)

    {:ok, %Interface{} = interface} =
      Interfaces.install_interface(realm, Jason.decode!(interface_json))

    table_name =
      CQLUtils.interface_name_to_table_name(interface.name, interface.major_version)

    """
    INSERT INTO #{keyspace}.#{table_name}
    (device_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis)
    VALUES (?, ?, ?, ?, ?)
    """
    |> Repo.query!([
      device_id,
      "/example/path",
      value_timestamp,
      reception_timestamp,
      reception_timestamp_submillis
    ])

    %Device{
      device_id: device_id,
      introspection: %{interface.name => interface.major_version}
    }
    |> Repo.insert!(prefix: keyspace)

    on_exit(fn ->
      capture_log(fn ->
        Queries.delete_interface(realm, interface.name, interface.major_version)
      end)
    end)
  end
end
