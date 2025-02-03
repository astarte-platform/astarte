#
# This file is part of Astarte.
#
# Copyright 2019 - 2025 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.Stats.DevicesStats do
  alias Astarte.DataAccess.Astarte.Realm
  alias Astarte.DataAccess.Realms.Device
  alias Astarte.DataAccess.Repo

  import Ecto.Query

  defstruct [
    :total_devices,
    :connected_devices
  ]

  def for_realm(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    device_count = Repo.aggregate(Device, :count, prefix: keyspace)

    # TODO: we should do this via DataUpdaterPlant instead of using ALLOW FILTERING
    online_query =
      from Device,
        hints: ["ALLOW FILTERING"],
        prefix: ^keyspace,
        where: [connected: true]

    online_count = Repo.aggregate(online_query, :count)

    %__MODULE__{
      total_devices: device_count,
      connected_devices: online_count
    }
  end
end
