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

defmodule Astarte.AppEngine.API.Device.DeviceV2ReadingTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.InterfaceValues

  import Astarte.Helpers.Device
  import Astarte.InterfaceValuesRetrievealGenerators

  setup_all :populate_interfaces

  describe "get_interface_values!/5" do
    property "allows downsampling individual datastreams", context do
      %{
        realm_name: realm_name,
        device: device,
        registered_paths: registered_paths,
        interfaces_with_data: interfaces_with_data
      } = context

      downsampable_interfaces =
        interfaces_with_data
        |> Enum.filter(&downsampable?/1)
        |> Enum.filter(&(&1.aggregation == :individual))

      downsampable_paths =
        downsampable_interfaces
        |> Enum.map(fn interface ->
          {interface, downsampable_paths(realm_name, interface, registered_paths)}
        end)
        |> Enum.reject(fn {_interface, paths} -> Enum.empty?(paths) end)
        |> Map.new()

      downsampable_interfaces = Map.keys(downsampable_paths)

      check all interface <- member_of(downsampable_interfaces),
                "/" <> path <- member_of(downsampable_paths[interface]),
                downsample_to <- integer(3..100),
                opts <- interface_values_options(downsample_to: downsample_to) do
        {:ok, %InterfaceValues{data: result}} =
          Device.get_interface_values!(
            realm_name,
            device.encoded_id,
            interface.name,
            path,
            opts
          )

        assert result_size(result) <= downsample_to
      end
    end
  end

  defp result_size(result) when is_list(result), do: Enum.count(result)
  defp result_size(%{"value" => result}), do: result_size(result)
  defp result_size(_single_result), do: 1
end
