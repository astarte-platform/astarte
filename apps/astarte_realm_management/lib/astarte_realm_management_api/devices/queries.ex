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

defmodule Astarte.RealmManagement.API.Devices.Queries do
  alias Astarte.DataAccess.Devices.Device, as: RealmsDevice
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Consistency

  import Ecto.Query

  def insert_device_into_deletion_in_progress(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    deletion = %DeletionInProgress{
      device_id: device_id,
      vmq_ack: false,
      dup_start_ack: false,
      dup_end_ack: false
    }

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:write)
    ]

    Repo.insert!(deletion, opts)
    :ok
  end

  def check_device_exists(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from device in RealmsDevice,
        select: device.device_id,
        where: [device_id: ^device_id]

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    Repo.some?(query, opts)
  end
end
