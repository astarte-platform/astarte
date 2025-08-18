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
defmodule Astarte.Core.Generators.Interface do
  @moduledoc """
  This module provides generators for Astarte Interface.

  See https://docs.astarte-platform.org/astarte/latest/030-interface.html
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  alias Astarte.Core.Generators.Mapping, as: MappingGenerator

  alias Astarte.Utilities.Map, as: MapUtilities

  @interface_max_mappings 10

  @doc """
  Generates a valid Astarte Interface.

  https://github.com/astarte-platform/astarte_core/blob/master/lib/astarte_core/interface.ex
  """
  @spec interface(params :: keyword()) :: StreamData.t(Interface.t())
  def interface(params \\ []) do
    params gen all name <- name(),
                   major_version <- major_version(),
                   minor_version <- minor_version(major_version),
                   id <- id(name, major_version),
                   type <- type(),
                   ownership <- ownership(),
                   aggregation <- aggregation(type),
                   mappings <- mappings(aggregation, type, name, major_version),
                   description <- description(),
                   doc <- doc(),
                   params: params do
      fields =
        MapUtilities.clean(%{
          interface_id: id,
          name: name,
          major_version: major_version,
          minor_version: minor_version,
          type: type,
          ownership: ownership,
          aggregation: aggregation,
          mappings: mappings,
          description: description,
          doc: doc
        })

      struct(Interface, fields)
    end
  end

  @doc """
  Convert this struct/stream to changes
  """
  @spec to_changes(Interface.t()) :: StreamData.t(map())
  def to_changes(data) when not is_struct(data, StreamData),
    do: data |> constant() |> to_changes()

  @spec to_changes(StreamData.t(Interface.t())) :: StreamData.t(map())
  def to_changes(gen) do
    gen all %Interface{
              name: name,
              major_version: major_version,
              minor_version: minor_version,
              type: type,
              ownership: ownership,
              aggregation: aggregation,
              mappings: mappings,
              description: description,
              doc: doc
            } <-
              gen,
            mappings <-
              mappings
              |> Enum.map(&MappingGenerator.to_changes(constant(&1)))
              |> fixed_list() do
      MapUtilities.clean(%{
        name: name,
        major_version: major_version,
        minor_version: minor_version,
        type: type,
        ownership: ownership,
        aggregation: aggregation,
        mappings: mappings,
        description: description,
        doc: doc,
        # Different input naming
        interface_name: name,
        version_major: major_version,
        version_minor: minor_version
      })
    end
  end

  @doc """
  Generates a valid Astarte Interface name.

  https://docs.astarte-platform.org/astarte/latest/030-interface.html#name-limitations
  """
  @spec name() :: StreamData.t(String.t())
  def name do
    gen all optional_part <- name_optional(),
            required_part <- name_required(optional_part) do
      optional_part <> required_part
    end
  end

  @doc """
  Generates a valid Astarte Interface type.

  https://docs.astarte-platform.org/astarte/latest/030-interface.html#interface-type
  """
  @spec type() :: StreamData.t(:datastream | :properties)
  def type, do: member_of([:datastream, :properties])

  @doc false
  @spec aggregation(any()) :: StreamData.t(:individual | :object)
  def aggregation(:properties), do: constant(:individual)
  def aggregation(_), do: member_of([:individual, :object])

  @doc false
  @spec major_version :: StreamData.t(integer())
  def major_version, do: integer(0..9)

  defp name_optional do
    gen all first <- string([?a..?z, ?A..?Z], length: 1),
            rest <- string(:alphanumeric, max_length: 10),
            repeating <- list_of(name_repeating(), max_length: 5) do
      initial = first <> rest
      repeating = Enum.join(repeating)
      initial <> "." <> repeating
    end
    |> filter(&(String.length(&1) < 127))
  end

  defp name_repeating do
    gen all initial <- string(:alphanumeric, length: 1),
            rest <- string([?a..?z, ?A..?Z, ?0..?9, ?-], max_length: 10) do
      initial <> rest <> "."
    end
  end

  defp name_required(name_optional) do
    max_length = 127 - String.length(name_optional)

    gen all first <- string([?a..?z, ?A..?Z], length: 1),
            rest <- string(:alphanumeric, max_length: max_length) do
      first <> rest
    end
  end

  defp id(interface_name, major_version),
    do: constant(CQLUtils.interface_id(interface_name, major_version))

  defp minor_version(major_version) do
    case major_version do
      0 -> integer(1..255)
      _n -> integer(0..255)
    end
  end

  defp ownership, do: member_of([:device, :server])

  defp interface_mapping(params, endpoint),
    do: MappingGenerator.mapping(params ++ [endpoint: endpoint])

  defp interface_mappings(:individual, params) do
    MappingGenerator.endpoint()
    |> bind(&interface_mapping(params, &1))
    |> list_of(min_length: 1, max_length: @interface_max_mappings)
    |> map(&uniq_endpoints/1)
  end

  defp interface_mappings(:object, params) do
    MappingGenerator.endpoint()
    |> bind(fn endpoint ->
      MappingGenerator.endpoint_segment()
      |> bind(&interface_mapping(params, endpoint <> &1))
      |> list_of(min_length: 1, max_length: @interface_max_mappings)
      |> map(&uniq_endpoints/1)
    end)
  end

  defp mappings(aggregation, interface_type, interface_name, interface_major) do
    common =
      gen all retention <- MappingGenerator.retention(interface_type),
              reliability <- MappingGenerator.reliability(interface_type),
              expiry <- MappingGenerator.expiry(interface_type),
              allow_unset <- MappingGenerator.allow_unset(interface_type),
              explicit_timestamp <- MappingGenerator.explicit_timestamp(interface_type) do
        [
          retention: retention,
          reliability: reliability,
          expiry: expiry,
          allow_unset: allow_unset,
          explicit_timestamp: explicit_timestamp
        ]
      end

    gen all common_params <- common,
            other_params = [
              interface_type: interface_type,
              interface_name: interface_name,
              interface_major: interface_major
            ],
            params = common_params ++ other_params,
            mappings <- interface_mappings(aggregation, params) do
      mappings
    end
  end

  defp description, do: one_of([nil, string(:ascii, min_length: 1, max_length: 1000)])

  defp doc, do: one_of([nil, string(:ascii, min_length: 1, max_length: 100_000)])

  # Utilities

  @normalized_param ""

  @doc false
  @spec uniq_endpoints(list(Mapping.t())) :: list(Mapping.t())
  def uniq_endpoints([%Mapping{} | _] = mappings),
    do: mappings |> uniq_endpoints(MapSet.new(), MapSet.new())

  defp uniq_endpoints([], _endpoints, acc), do: MapSet.to_list(acc)

  defp uniq_endpoints([%Mapping{endpoint: endpoint} = mapping | rest], prefixes, acc) do
    prefix = endpoint |> uniform_param() |> tokenize_endpoint()

    if conflict_exists?(prefixes, prefix) do
      uniq_endpoints(rest, prefixes, acc)
    else
      uniq_endpoints(rest, MapSet.put(prefixes, prefix), MapSet.put(acc, mapping))
    end
  end

  defp tokenize_endpoint(endpoint), do: endpoint |> String.split("/") |> Enum.drop(1)

  defp conflict?([], _), do: true
  defp conflict?(_, []), do: true
  defp conflict?([@normalized_param | ta], [_ | tb]), do: conflict?(ta, tb)
  defp conflict?([_ | ta], [@normalized_param | tb]), do: conflict?(ta, tb)
  defp conflict?([h | ta], [h | tb]), do: conflict?(ta, tb)
  defp conflict?(_, _), do: false

  defp conflict_exists?(prefixes, test), do: Enum.any?(prefixes, &conflict?(&1, test))

  defp uniform_param(endpoint), do: Mapping.normalize_endpoint(endpoint) |> String.downcase()
end
