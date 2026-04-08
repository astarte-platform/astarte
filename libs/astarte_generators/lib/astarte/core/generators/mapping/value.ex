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

  @type individual_type_t() :: ValueTypeGenerator.valid_t()
  @type object_type_t() :: %{String.t() => ValueTypeGenerator.valid_t()}
  @type individual_value_t :: any()
  @type object_value_t :: %{String.t() => any()}

  @type type_t() :: individual_type_t() | object_type_t()
  @type value_t() :: individual_value_t() | object_value_t()
  @type t() :: %{path: String.t(), type: type_t(), value: value_t()}

  @doc """
  Generates a valid value based on interface passed or auto-created
  """
  @spec value() :: StreamData.t(t())
  @spec value(params :: keyword()) :: StreamData.t(t())
  def value(params \\ []) do
    gen_interface_base =
      params gen all interface <- InterfaceGenerator.interface(), params: params do
        interface
      end

    gen_interface_base |> bind(fn interface -> build_package(interface, params) end)
  end

  @doc """
  Create a `object_value_t` based on a map of `object_type_t`
  """
  @spec object_value_from_type(object_type_t()) :: StreamData.t(object_value_t())
  def object_value_from_type(%{} = type) when not is_struct(type, StreamData),
    do: type |> constant() |> object_value_from_type()

  @spec object_value_from_type(StreamData.t(object_type_t())) :: StreamData.t(object_value_t())
  def object_value_from_type(type),
    do:
      type
      |> bind(
        &(Map.new(&1, fn {postfix, type} -> {postfix, build_value(type)} end)
          |> fixed_map())
      )

  defp build_package(%Interface{aggregation: :individual = aggregation} = interface, params) do
    %Interface{mappings: mappings} = interface

    params gen all %Mapping{endpoint: endpoint, value_type: value_type} <- member_of(mappings),
                   type <- constant(value_type),
                   endpoint = InterfaceGenerator.endpoint_by_aggregation(aggregation, endpoint),
                   path <- path_from_endpoint(endpoint),
                   value <- build_value(type),
                   params: params do
      %{path: path, value: value, type: type}
    end
  end

  defp build_package(%Interface{aggregation: :object = aggregation} = interface, params) do
    %Interface{mappings: [%Mapping{endpoint: endpoint} | _] = mappings} = interface

    endpoint = InterfaceGenerator.endpoint_by_aggregation(aggregation, endpoint)

    params gen all path <- path_from_endpoint(endpoint),
                   type <-
                     mappings
                     |> Map.new(fn %Mapping{endpoint: endpoint, value_type: value_type} ->
                       {endpoint_postfix(endpoint), value_type}
                     end)
                     |> optional_map(),
                   value <- object_value_from_type(type),
                   params: params do
      %{path: path, value: value, type: type}
    end
  end

  defp endpoint_postfix(endpoint), do: Regex.replace(~r/.*\//, endpoint, "")

  defp build_value(value_type), do: ValueTypeGenerator.value_from_type(value_type)

  # Utilities

  @doc """
  Returns true if `path` matches `endpoint` according to the given `aggregation`.
  """
  @spec path_matches_endpoint?(:individual | :object, String.t(), String.t()) :: boolean()
  def path_matches_endpoint?(aggregation, endpoint, path),
    do:
      path_matches_endpoint?(
        InterfaceGenerator.endpoint_by_aggregation(aggregation, endpoint)
        |> Mapping.normalize_endpoint()
        |> String.split("/"),
        path |> String.split("/")
      )

  defp path_matches_endpoint?([], []), do: true

  defp path_matches_endpoint?(["" | endpoints], [_ | paths]),
    do: path_matches_endpoint?(endpoints, paths)

  defp path_matches_endpoint?([same | endpoints], [same | paths]),
    do: path_matches_endpoint?(endpoints, paths)

  defp path_matches_endpoint?(_, _), do: false

  @doc false
  @spec path_from_endpoint(endpoint :: String.t()) :: StreamData.t(String.t())
  def path_from_endpoint(endpoint) do
    endpoint
    |> String.split("/")
    |> Enum.map(&convert_token/1)
    |> fixed_list()
    |> map(&Enum.join(&1, "/"))
  end

  @doc """
  Returns type and value once given the Value package and the full search path.
  """
  @spec type_value_from_path(:individual | :object, String.t(), map()) ::
          %{type: ValueTypeGenerator.valid_t(), value: any()} | :error
  def type_value_from_path(:individual, search_path, %{
        path: search_path,
        type: type,
        value: value
      }),
      do: %{type: type, value: value}

  def type_value_from_path(:individual, _, _), do: :error

  def type_value_from_path(:object, search_path, %{path: base_path, type: type, value: value}),
    do:
      type_value_from_path(
        search_path,
        Enum.map(type, fn {postfix, type} ->
          {base_path <> "/" <> postfix, type, Map.fetch!(value, postfix)}
        end)
      )

  defp type_value_from_path(_search_path, []), do: :error

  defp type_value_from_path(search_path, [{search_path, type, value} | _]),
    do: %{type: type, value: value}

  defp type_value_from_path(search_path, [_ | tail]), do: type_value_from_path(search_path, tail)

  defp convert_token(token) do
    case Mapping.is_placeholder?(token) do
      true -> string(:alphanumeric, min_length: 1)
      false -> constant(token)
    end
  end
end
