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

defmodule Astarte.DataUpdaterPlant.RPC.Queries do
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataUpdaterPlant.Repo
  alias Astarte.DataUpdaterPlant.RPC.Device
  import Ecto.Query
  require Logger

  def fetch_connected_devices(realm_name) do
    statement = """
    SELECT *
    FROM #{realm_name}.devices
    WHERE connected = true
    ALLOW FILTERING
    """

    results =
      Xandra.Cluster.run(
        :xandra,
        &Xandra.execute!(&1, statement, %{}, consistency: Consistency.domain_model(:read))
      )

    connected_devices =
      Enum.map(results, fn %{"device_id" => device_id, "groups" => groups} ->
        group_names = Map.keys(groups || %{})

        Logger.info("Group names: #{inspect(group_names)}")

        %Device{
          device_id: device_id,
          realm: realm_name,
          groups: group_names
        }
      end)

    {:ok, connected_devices}
  end

  def fetch_realms! do
    statement = """
    SELECT *
    FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
    """

    realms =
      Xandra.Cluster.run(
        :xandra,
        &Xandra.execute!(&1, statement, %{}, consistency: Consistency.domain_model(:read))
      )

    Enum.map(realms, fn %{"realm_name" => realm_name} -> realm_name end)
  end
end
