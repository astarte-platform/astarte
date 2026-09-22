#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.Adapters.Device do
  @moduledoc """
  Mappings to Astarte.DataAccess.Devices.Device.
  """
  use Astarte.Adapters

  alias Astarte.Core.Interface
  alias Astarte.DataAccess.Groups.GroupedDevice

  @type source :: %{
          required(:device) => map(),
          required(:interfaces) => [Interface.t()],
          optional(:grouped_devices) => [GroupedDevice.t()]
        }

  transform from_core_device_to_change do
    @source source()
    @returns map()

    pre_process &pre_process/1

    keep :device_id,
         :connected,
         :inhibit_credentials_request,
         :total_received_bytes,
         :total_received_msgs

    field :aliases <- :aliases, required: false
    field :attributes <- :attributes, required: false
    field :capabilities <- :capabilities, required: false
    field :cert_aki <- :cert_aki, required: false
    field :cert_serial <- :cert_serial, required: false
    field :credentials_secret <- :credentials_secret, required: false
    field :first_credentials_request <- :first_credentials_request, required: false
    field :first_registration <- :first_registration, required: false
    field :last_connection <- :last_connection, required: false
    field :last_credentials_request_ip <- :last_credentials_request_ip, required: false
    field :last_disconnection <- :last_disconnection, required: false
    field :last_seen_ip <- :last_seen_ip, required: false
    field :pending_empty_cache <- :pending_empty_cache, required: false
    field :protocol_revision <- :protocol_revision, required: false
    field :shared_secret <- :shared_secret, required: false
    field :exchanged_bytes_by_interface <- :interfaces_bytes, required: false
    field :exchanged_msgs_by_interface <- :interfaces_msgs, required: false
    field :groups <- :grouped_devices, &groups/1
    field :introspection <- :interfaces, &introspection/1
    field :introspection_minor <- :interfaces, &introspection_minor/1
  end

  defp pre_process(%{
         device: device,
         grouped_devices: grouped_devices,
         interfaces: interfaces
       }),
       do:
         device
         |> Map.put(:grouped_devices, grouped_devices)
         |> Map.put(:interfaces, interfaces)

  defp pre_process(%{device: device, interfaces: interfaces}),
    do:
      device
      |> Map.put(:grouped_devices, [])
      |> Map.put(:interfaces, interfaces)

  defp groups(grouped_devices),
    do: Map.new(grouped_devices, &{&1.group_name, &1.insertion_uuid})

  defp introspection(interfaces),
    do: Map.new(interfaces, &{&1.name, &1.major_version})

  defp introspection_minor(interfaces),
    do: Map.new(interfaces, &{&1.name, &1.minor_version})
end
