#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Astarte.RealmManagement.Generators.IndividualDatastream do
  @moduledoc """
  Generator of `IndividualDatastream`s.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  alias Astarte.DataAccess.Realms.IndividualDatastream

  alias Astarte.Common.Generators.DateTime, as: DateTimeGenerator
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator

  @doc false
  @spec individual_datastream(params :: keyword()) :: StreamData.t(IndividualDatastream.t())
  def individual_datastream(params \\ []) do
    params gen all interface <-
                     InterfaceGenerator.interface(aggregation: :individual, type: :datastream),
                   value <- ValueGenerator.value(interface: interface),
                   device_id <- DeviceGenerator.id(),
                   value_timestamp <- DateTimeGenerator.date_time(),
                   reception_timestamp <- DateTimeGenerator.date_time(),
                   reception_timestamp_submillis <- integer(0..10),
                   %Interface{
                     interface_id: interface_id,
                     mappings: [%Mapping{endpoint_id: endpoint_id} | _]
                   } = interface,
                   %{path: path} = value,
                   params: params do
      %IndividualDatastream{
        interface_id: interface_id,
        device_id: device_id,
        endpoint_id: endpoint_id,
        path: path,
        value_timestamp: value_timestamp,
        reception_timestamp: reception_timestamp,
        reception_timestamp_submillis: reception_timestamp_submillis
      }
    end
  end
end
