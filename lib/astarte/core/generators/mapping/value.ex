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

defmodule Astarte.Core.Generators.Mapping.Value do
  @moduledoc """
  This module provides generators for Interface values.
  """
  use ExUnitProperties
  use Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping.ValueType, as: ValueTypeGenerator

  @doc """
  Generates a valid value based on interface passed or auto-created
  """
  @spec value() :: StreamData.t(map())
  @spec value(params :: keyword()) :: StreamData.t(map())
  def value(params \\ []) do
    gen_interface_base =
      params gen all interface <- InterfaceGenerator.interface(), params: params do
        interface
      end

    gen_interface_base |> bind(&build_package/1)
  end

  defp build_package(%Interface{aggregation: :individual} = interface) do
    %Interface{mappings: mappings} = interface

    gen all %Mapping{endpoint: endpoint, value_type: value_type} <- member_of(mappings),
            path <- endpoint_path(endpoint),
            value <- build_value(value_type) do
      %{path: path, value: value}
    end
  end

  defp build_package(%Interface{aggregation: :object} = interface) do
    %Interface{mappings: [%Mapping{endpoint: endpoint} | _] = mappings} = interface

    endpoint = endpoint |> String.split("/") |> Enum.drop(-1) |> Enum.join("/")

    gen all path <- endpoint_path(endpoint),
            value <-
              mappings
              |> Map.new(fn %Mapping{endpoint: endpoint, value_type: value_type} ->
                {endpoint_postfix(endpoint), build_value(value_type)}
              end)
              |> optional_map() do
      %{path: path, value: value}
    end
  end

  defp endpoint_path(endpoint) do
    endpoint
    |> String.split("/")
    |> Enum.map(&convert_token/1)
    |> fixed_list()
    |> map(&Enum.join(&1, "/"))
  end

  defp endpoint_postfix(endpoint), do: Regex.replace(~r/.*\//, endpoint, "")

  defp build_value(value_type), do: ValueTypeGenerator.value_from_type(value_type)

  # Utilities
  defp convert_token(token) do
    case(Mapping.is_placeholder?(token)) do
      true -> string(:alphanumeric, min_length: 1)
      false -> constant(token)
    end
  end

  @doc """
  Returns true if `path` matches `endpoint` according to the given `aggregation`.
  """
  @spec path_matches_endpoint?(:individual | :object, String.t(), String.t()) :: boolean()
  def path_matches_endpoint?(:individual, endpoint, path),
    do:
      path_matches_endpoint?(
        endpoint |> Mapping.normalize_endpoint() |> String.split("/"),
        path |> String.split("/")
      )

  def path_matches_endpoint?(:object, endpoint, path),
    do:
      path_matches_endpoint?(
        endpoint |> Mapping.normalize_endpoint() |> String.split("/") |> Enum.drop(-1),
        path |> String.split("/")
      )

  defp path_matches_endpoint?([], []), do: true

  defp path_matches_endpoint?(["" | endpoints], [_ | paths]),
    do: path_matches_endpoint?(endpoints, paths)

  defp path_matches_endpoint?([same | endpoints], [same | paths]),
    do: path_matches_endpoint?(endpoints, paths)

  defp path_matches_endpoint?(_, _), do: false
end
