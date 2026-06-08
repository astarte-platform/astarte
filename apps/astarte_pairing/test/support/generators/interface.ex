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

defmodule Astarte.Generators.Interface do
  @moduledoc false
  use ExUnitProperties

  alias Astarte.Core.Interface

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  @doc false
  @spec interface_list() :: StreamData.t(list(Interface.t()))
  def interface_list do
    gen all individual_datastream_device <- individual_datastream(:device),
            individual_datastream_server <- individual_datastream(:server),
            object_datastream_device <- object_datastream(:device),
            object_datastream_server <- object_datastream(:server),
            properties_device <- properties(:device),
            properties_server <- properties(:server),
            other <- other() do
      [
        individual_datastream_device,
        individual_datastream_server,
        object_datastream_device,
        object_datastream_server,
        properties_device,
        properties_server,
        other
      ]
    end
  end

  defp individual_datastream(ownership),
    do:
      InterfaceGenerator.interface(
        ownership: ownership,
        aggregation: :individual,
        type: :datastream
      )

  defp object_datastream(ownership),
    do:
      InterfaceGenerator.interface(ownership: ownership, aggregation: :object, type: :datastream)

  defp properties(ownership) do
    InterfaceGenerator.interface(ownership: ownership, type: :properties)
  end

  defp other, do: InterfaceGenerator.interface()
end
