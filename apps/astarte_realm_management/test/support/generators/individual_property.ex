#
# This file is part of Astarte.
#
# Copyright 2025 SECO - 2026 Mind Srl
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

defmodule Astarte.RealmManagement.Generators.IndividualProperty do
  @moduledoc """
  Generators of `IndividualProperty`es
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  alias Astarte.DataAccess.Realms.IndividualProperty

  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator

  @doc false
  @spec individual_property(params :: keyword()) :: StreamData.t(IndividualProperty.t())
  def individual_property(params \\ []) do
    params gen all interface <-
                     InterfaceGenerator.interface(aggregation: :individual, type: :properties),
                   value <- ValueGenerator.value(interface: interface),
                   device_id <- DeviceGenerator.id(),
                   %Interface{
                     interface_id: interface_id,
                     mappings: [%Mapping{endpoint_id: endpoint_id} | _]
                   } = interface,
                   %{path: path} = value,
                   params: params do
      %IndividualProperty{
        device_id: device_id,
        interface_id: interface_id,
        endpoint_id: endpoint_id,
        path: path
      }
    end
  end
end
