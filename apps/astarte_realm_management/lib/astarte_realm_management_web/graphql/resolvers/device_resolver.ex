#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.RealmManagementWeb.GraphQL.Resolvers.DeviceResolver do
  @moduledoc false
  alias Astarte.RealmManagement.Devices

  def delete_device(_parent, %{device_id: device_id}, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    case Devices.delete_device(realm_name, device_id) do
      :ok -> {:ok, "Device deletion initiated"}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def delete_device(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  defp format_error(reason), do: inspect(reason)
end
