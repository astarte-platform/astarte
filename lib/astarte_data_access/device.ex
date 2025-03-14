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

defmodule Astarte.DataAccess.Device do
  require Logger
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.XandraUtils
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.Repo
  alias Astarte.Core.Device, as: DeviceCore
  import Ecto.Query

  @spec interface_version(String.t(), DeviceCore.device_id(), String.t()) ::
          {:ok, integer} | {:error, atom}
  def interface_version(realm, device_id, interface_name) do
    keyspace = Realm.keyspace_name(realm)
    consistency = Consistency.device_info(:read)

    device_fetch =
      Device
      |> where(device_id: ^device_id)
      |> select([:introspection])
      |> Repo.fetch_one(error: :device_not_found, prefix: keyspace, consistency: consistency)

    with device <- device_fetch,
         {:ok, major} <- retrieve_major(device, interface_name) do
      {:ok, major}
    end
  end

  defp retrieve_major(%{introspection: introspection}, interface_name) do
    case introspection do
      %{^interface_name => major} -> {:ok, major}
      _ -> {:error, :interface_not_in_introspection}
    end
  end

  defp retrieve_major(nil, _) do
    {:error, :device_not_found}
  end
end
