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

  alias Astarte.Core.Generators.Mapping, as: MappingGenerator
  alias Astarte.Core.Interface
  alias Astarte.Generators.Utilities.ParamsGen
  alias Ecto.UUID

  import ParamsGen

  @doc """
  Generates a valid Astarte Interface.

  https://github.com/astarte-platform/astarte_core/blob/master/lib/astarte_core/interface.ex
  """
  @spec interface(params :: Keyword.t()) :: StreamData.t(Interface.t())
  def interface(params \\ []) do
    gen all required <- required_fields(params),
            optional <- optional_fields(params) do
      struct(Interface, Map.merge(required, optional))
    end
  end

  defp id, do: repeatedly(&UUID.bingenerate/0)

  defp name do
    gen all optional_part <- name_optional(),
            required_part <- name_required(optional_part) do
      optional_part <> required_part
    end
  end

  defp minor_version(major_version) do
    case major_version do
      0 -> integer(1..255)
      _n -> integer(0..255)
    end
  end

  defp type, do: member_of([:datastream, :properties])

  defp ownership, do: member_of([:device, :server])

  defp mappings(interface_type, config) do
    uniq_list_of(MappingGenerator.mapping(interface_type, config),
      min_length: 1,
      max_length: 1000
    )
  end

  defp aggregation(%{type: :properties}), do: constant(:individual)
  defp aggregation(_), do: member_of([:individual, :object])

  defp description do
    string(:ascii, min_length: 1, max_length: 1000)
  end

  defp doc do
    string(:ascii, min_length: 1, max_length: 100_000)
  end

  defp endpoint_subpath do
    string([?a..?z, ?_], min_length: 1, max_length: 5)
  end

  @spec endpoint_parametric_subpath() :: StreamData.t(any())
  def endpoint_parametric_subpath do
    gen all(subpath <- endpoint_subpath()) do
      "%{" <> subpath <> "}"
    end
  end

  defp endpoint_prefix do
    gen all(
          prefix <-
            frequency([
              {1, endpoint_subpath()},
              {1, endpoint_parametric_subpath()}
            ])
            |> list_of(
              min_length: 1,
              max_length: 5
            )
            |> map(&Enum.join(&1, "/"))
        ) do
      "/" <> prefix
    end
  end

  defp required_fields(params) do
    params gen all id <- id(),
                   name <- name(),
                   major_version <- integer(0..9),
                   minor_version <- minor_version(major_version),
                   type <- type(),
                   aggregation <- aggregation(%{type: type}),
                   ownership <- ownership(),
                   prefix <- endpoint_prefix(),
                   retention <- retention_for(type),
                   reliability <- reliability_for(type),
                   expiry <- expiry_for(type),
                   allow_unset <- allow_unset_for(type),
                   explicit_timestamp <- explicit_timestamp_for(type),
                   mappings <-
                     mappings(type, %{
                       aggregation: aggregation,
                       prefix: prefix,
                       retention: retention,
                       reliability: reliability,
                       expiry: expiry,
                       allow_unset: allow_unset,
                       explicit_timestamp: explicit_timestamp
                     }),
                   params: params do
      %{
        id: id,
        interface_id: id,
        name: name,
        interface_name: name,
        major_version: major_version,
        minor_version: minor_version,
        version_major: major_version,
        version_minor: minor_version,
        type: type,
        interface_type: type,
        ownership: ownership,
        aggregation: aggregation,
        mappings: mappings
      }
    end
  end

  defp optional_fields(params) do
    params gen all description <- optional(description()),
                   doc <- optional(doc()),
                   params: params do
      %{description: description, doc: doc}
    end
  end

  defp optional(generator) do
    one_of([generator, nil])
  end

  defp retention_for(:datastream), do: MappingGenerator.retention()
  defp retention_for(:properties), do: constant(:discard)
  defp reliability_for(:datastream), do: MappingGenerator.reliability()
  defp reliability_for(:properties), do: constant(:unreliable)
  defp expiry_for(:datastream), do: MappingGenerator.expiry()
  defp expiry_for(:properties), do: constant(0)
  defp allow_unset_for(:datastream), do: constant(false)
  defp allow_unset_for(:properties), do: MappingGenerator.allow_unset()
  defp explicit_timestamp_for(:datastream), do: MappingGenerator.explicit_timestamp()
  defp explicit_timestamp_for(:properties), do: constant(false)

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
end
