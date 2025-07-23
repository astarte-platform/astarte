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
    interfaces = [
      InterfaceGenerator.interface(
        aggregation: :object,
        type: :datastream
      )
      |> Enum.at(0),
      InterfaceGenerator.interface(
        aggregation: :individual,
        type: :properties
      )
      |> Enum.at(0)
    ]

    Enum.each(interfaces, &install_interface!/1)

    {:ok, interfaces}
  end

  def install_interface!(interface) do
    base_url = Config.realm_management_url!()
    realm = Config.realm!()
    astarte_jwt = Config.jwt!()

    url = "#{base_url}/v1/#{realm}/interfaces"

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"}
    ]

    body = %{"data" => interface} |> Jason.encode!()

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        {:cont, :ok}

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:halt, {:error, %{status: code, body: body}}}

      {:error, %HTTPoison.Error{} = error} ->
        {:halt, {:error, error}}
    end
  end

  def interface_to_map(interface) do
    interface
    |> Map.from_struct()
    |> Map.put(:interface_name, interface.name)
    |> Map.put(:version_major, interface.major_version)
    |> Map.put(:version_minor, interface.minor_version)
    |> Map.update!(:mappings, fn mappings ->
      Enum.map(mappings, fn %Astarte.Core.Mapping{} = mapping ->
        mapping
        |> Map.from_struct()
        |> Map.put_new(:type, mapping.value_type || :string)
        |> Map.put_new(:value_type, mapping.value_type || :string)
      end)
    end)
  end
end
