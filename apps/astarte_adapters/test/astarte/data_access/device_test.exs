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

defmodule Astarte.DataAccess.Adapters.DeviceTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Device
  import Astarte.Core.Generators.Group
  import Astarte.Core.Generators.Interface
  import Astarte.DataAccess.Adapters.Device

  alias Astarte.Core.Device.Capabilities
  alias Astarte.DataAccess.Devices.Device
  alias COSE.Keys.Symmetric

  @direct_fields [
    :aliases,
    :attributes,
    :capabilities,
    :cert_aki,
    :cert_serial,
    :connected,
    :credentials_secret,
    :device_id,
    :first_credentials_request,
    :first_registration,
    :inhibit_credentials_request,
    :last_connection,
    :last_credentials_request_ip,
    :last_disconnection,
    :last_seen_ip,
    :pending_empty_cache,
    :protocol_revision,
    :shared_secret,
    :total_received_bytes,
    :total_received_msgs
  ]

  describe "from core device to data access changes" do
    property "maps a data access device" do
      check all %{
                  changes:
                    %{
                      groups: groups,
                      introspection: introspection,
                      introspection_minor: introspection_minor
                    } = changes,
                  source:
                    %{
                      grouped_devices: grouped_devices,
                      interfaces: interfaces,
                      interfaces_bytes: interfaces_bytes,
                      interfaces_msgs: interfaces_msgs
                    } = source
                } <- adapted_device() do
        assert %Device{} = struct(Device, changes)

        for field <- @direct_fields do
          assert Map.get(changes, field) == Map.get(source, field)
        end

        assert Map.get(changes, :exchanged_bytes_by_interface) == interfaces_bytes
        assert Map.get(changes, :exchanged_msgs_by_interface) == interfaces_msgs
        assert groups == Map.new(grouped_devices, &{&1.group_name, &1.insertion_uuid})
        assert introspection == Map.new(interfaces, &{&1.name, &1.major_version})
        assert introspection_minor == Map.new(interfaces, &{&1.name, &1.minor_version})
      end
    end
  end

  defp adapted_device do
    gen all interfaces <- interface() |> list_of(max_length: 5),
            device <- device(interfaces: interfaces),
            group_names <- group_name() |> uniq_list_of(max_length: 5),
            insertion_uuids <- binary(length: 16) |> list_of(length: length(group_names)) do
      grouped_devices =
        for {group_name, insertion_uuid} <- Enum.zip(group_names, insertion_uuids) do
          %{group_name: group_name, insertion_uuid: insertion_uuid}
        end

      source =
        device
        |> Map.merge(optional_fields())
        |> Map.merge(%{grouped_devices: grouped_devices, interfaces: interfaces})

      %{
        changes: from_core_device_to_change(source),
        source: source
      }
    end
  end

  defp optional_fields do
    %{
      capabilities: %Capabilities{},
      cert_aki: "aki",
      cert_serial: "serial",
      credentials_secret: "secret",
      pending_empty_cache: true,
      protocol_revision: 1,
      shared_secret: %Symmetric{alg: :aes_256_gcm, k: :crypto.strong_rand_bytes(32)}
    }
  end
end
