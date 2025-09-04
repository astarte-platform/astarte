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

defmodule AstarteE2E.Interface do
  require Logger

  alias AstarteE2E.Config
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  def generate_interfaces!() do
    [
      InterfaceGenerator.interface(
        aggregation: :individual,
        type: :datastream,
        ownership: :device
      ),
      InterfaceGenerator.interface(
        aggregation: :individual,
        type: :properties,
        ownership: :device
      )
    ]
    |> Enum.map(&InterfaceGenerator.to_changes/1)
    |> Enum.map(&Enum.at(&1, 0))
    |> Enum.map(&update_value_type/1)
  end

  def install_interfaces!(interfaces) do
    Enum.each(interfaces, &install_interface!/1)
    :ok
  end

  def install_interface!(interface) do
    base_url = Config.realm_management_url!()
    realm = Config.realm!()
    astarte_jwt = Config.jwt!()

    url = Path.join([base_url, "v1", realm, "interfaces"])

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"}
    ]

    body =
      %{
        "data" => interface
      }
      |> Jason.encode!()

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        :ok

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        raise "Failed to install interface: #{code} #{body}"

      {:error, %HTTPoison.Error{} = error} ->
        raise "HTTP error while installing interface: #{inspect(error)}"
    end
  end

  # temporary string only data
  defp update_value_type(interface_map) do
    updated_mappings =
      Enum.map(interface_map[:mappings], fn mapping ->
        Map.put(mapping, :value_type, :string)
        Map.put(mapping, :type, :string)
      end)

    Map.put(interface_map, :mappings, updated_mappings)
  end
end
