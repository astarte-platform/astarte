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

defmodule Astarte.Core.Generators.InterfaceUpdate do
  @moduledoc """
  Generates valid interface updates for API submission or database seeding.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Mapping.ValueType

  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  @type representation_t :: :api | :database
  @type value_type_t :: atom() | %{String.t() => atom()}
  @type t :: %{
          path: String.t(),
          aggregation: :individual | :object,
          reliability: :unreliable | :guaranteed | :unique,
          value: any(),
          value_type: value_type_t()
        }

  @doc """
  Generates a valid interface update using the requested representation.
  """
  @spec valid_mapping_update_for(Interface.t(), representation_t()) :: StreamData.t(t())
  @spec valid_mapping_update_for(Interface.t(), representation_t(), keyword()) ::
          StreamData.t(t())
  def valid_mapping_update_for(interface, representation, params \\ [])

  def valid_mapping_update_for(
        %Interface{aggregation: :individual, mappings: mappings, type: interface_type},
        representation,
        params
      ) do
    params gen all mapping <- member_of(mappings),
                   %Mapping{
                     endpoint: endpoint,
                     reliability: mapping_reliability,
                     value_type: value_type
                   } = mapping,
                   path <- ValueGenerator.path_from_endpoint(endpoint),
                   value <- valid_update_value_for(value_type, representation, params),
                   params: params do
      %{
        path: path,
        aggregation: :individual,
        reliability: reliability(interface_type, mapping_reliability),
        value: value,
        value_type: value_type
      }
    end
  end

  def valid_mapping_update_for(
        %Interface{aggregation: :object} = interface,
        representation,
        params
      ),
      do: object_mapping_update(interface, representation, params)

  @doc """
  Generates a valid represented value for one value type or an object value type map.
  """
  @spec valid_update_value_for(value_type_t(), representation_t()) :: StreamData.t(any())
  @spec valid_update_value_for(value_type_t(), representation_t(), keyword()) ::
          StreamData.t(any())
  def valid_update_value_for(value_type, representation, params \\ [])

  def valid_update_value_for(value_types, representation, params) when is_map(value_types),
    do:
      value_types
      |> Map.new(fn {key, value_type} ->
        {key, represented_value(value_type, representation, params)}
      end)
      |> fixed_map()

  def valid_update_value_for(value_type, representation, params) when is_atom(value_type),
    do: represented_value(value_type, representation, params)

  defp represented_value(value_type, representation, params),
    do:
      value_from_type(value_type,
        representation: representation,
        force_allow_unset: Keyword.get(params, :force_allow_unset, false)
      )

  defp reliability(:properties, _mapping_reliability), do: :unique
  defp reliability(:datastream, mapping_reliability), do: mapping_reliability

  defp object_mapping_update(interface, representation, params) do
    {endpoint, value_types, reliability} = object_interface_info(interface)

    params gen all value_type <- optional_map(value_types),
                   path <- ValueGenerator.path_from_endpoint(endpoint),
                   value <- valid_update_value_for(value_type, representation, params),
                   params: params do
      %{
        path: path,
        aggregation: :object,
        reliability: reliability,
        value: value,
        value_type: value_type
      }
    end
  end

  defp object_interface_info(%Interface{
         mappings: [%Mapping{endpoint: endpoint} | _] = mappings,
         type: interface_type
       }) do
    value_types =
      Map.new(mappings, fn %Mapping{endpoint: endpoint, value_type: value_type} ->
        {endpoint_postfix(endpoint), value_type}
      end)

    %Mapping{reliability: mapping_reliability} = List.first(mappings)

    {
      object_endpoint(endpoint),
      value_types,
      reliability(interface_type, mapping_reliability)
    }
  end

  defp object_endpoint(endpoint),
    do: endpoint |> String.split("/") |> Enum.drop(-1) |> Enum.join("/")

  defp endpoint_postfix(endpoint), do: endpoint |> String.split("/") |> List.last()
end
