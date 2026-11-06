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
defmodule Astarte.AppEngine.APIWeb.GraphQL.Types.DeviceTypes do
  @moduledoc """
  GraphQL types for the devices.
  """

  use Absinthe.Schema.Notation

  alias Astarte.AppEngine.API.Device.DeviceStatus

  @desc "A key and its value"
  object :map_entry do
    @desc "The key of the entry"
    field :key, non_null(:string)

    @desc "The value of the key"
    field :value, non_null(:string)
  end

  @desc "An interface of a device, with the traffic the device exchanged on it"
  object :interface_info do
    @desc "The name of the interface"
    field :name, non_null(:string)

    @desc "The major version of the interface"
    field :major, non_null(:integer)

    @desc "The minor version of the interface"
    field :minor, non_null(:integer)

    @desc "The number of messages exchanged on the interface"
    field :exchanged_msgs, non_null(:integer)

    @desc "The number of bytes exchanged on the interface"
    field :exchanged_bytes, non_null(:integer)
  end

  @desc "A device and its status"
  object :device do
    @desc "The ID of the device"
    field :id, non_null(:string)

    @desc "Whether the device is connected to the broker"
    field :connected, non_null(:boolean)

    @desc "The interfaces the device currently declares"
    field :introspection, non_null(list_of(non_null(:interface_info))) do
      resolve fn %DeviceStatus{introspection: introspection}, _args, _resolution ->
        {:ok, interface_infos(introspection)}
      end
    end

    @desc "The interfaces the device declared before, in a major version it no longer uses"
    field :previous_interfaces, non_null(list_of(non_null(:interface_info)))

    @desc "The aliases of the device, by tag"
    field :aliases, non_null(list_of(non_null(:map_entry))) do
      resolve fn %DeviceStatus{aliases: aliases}, _args, _resolution ->
        {:ok, map_entries(aliases)}
      end
    end

    @desc "The attributes of the device"
    field :attributes, non_null(list_of(non_null(:map_entry))) do
      resolve fn %DeviceStatus{attributes: attributes}, _args, _resolution ->
        {:ok, map_entries(attributes)}
      end
    end

    @desc "The names of the groups the device belongs to"
    field :groups, non_null(list_of(non_null(:string)))

    @desc "The number of messages received from the device"
    field :total_received_msgs, :integer

    @desc "The number of bytes received from the device"
    field :total_received_bytes, :integer

    @desc "When the device last connected"
    field :last_connection, :datetime

    @desc "When the device last disconnected"
    field :last_disconnection, :datetime

    @desc "When the device was registered"
    field :first_registration, :datetime

    @desc "When the device first requested its credentials"
    field :first_credentials_request, :datetime

    @desc "The IP address the device was last seen from"
    field :last_seen_ip, :string

    @desc "The IP address the device last requested its credentials from"
    field :last_credentials_request_ip, :string

    @desc "Whether the device is prevented from requesting new credentials"
    field :credentials_inhibited, :boolean

    @desc "Whether the device is being deleted"
    field :deletion_in_progress, non_null(:boolean)
  end

  defp interface_infos(introspection),
    do: Enum.map(introspection, fn {name, info} -> %{info | name: name} end)

  defp map_entries(map), do: Enum.map(map, fn {key, value} -> %{key: key, value: value} end)
end
