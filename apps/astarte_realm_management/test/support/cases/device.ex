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

defmodule Astarte.Cases.Device do
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Device

  use ExUnit.CaseTemplate
  use ExUnitProperties

  import Astarte.Helpers.Device

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup_all %{realm_name: realm_name} do
    interfaces = list_of(InterfaceGenerator.interface(), min_length: 1) |> Enum.at(0)
    device = DeviceGenerator.device(interfaces: interfaces) |> Enum.at(0)

    Enum.each(interfaces, &insert_interface_cleanly(realm_name, &1))

    insert_device_cleanly(realm_name, device, interfaces)
    encoded_device_id = Device.encode_device_id(device.device_id)

    %{interfaces: interfaces, device_id: encoded_device_id}
  end
end
