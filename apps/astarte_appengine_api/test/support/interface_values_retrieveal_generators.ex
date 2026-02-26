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

defmodule Astarte.InterfaceValuesRetrievealGenerators do
  @moduledoc """
  Generators for Astarte AppEngine API Device InterfaceValuesOptions.

  This module provides stream data generators to create valid options for 
  retrieving interface values, handling complex logic like downsampling 
  constraints based on the interface type.
  """

  alias Astarte.Helpers.Device

  use Astarte.Generators.Utilities.ParamsGen

  @doc """
  Generate valid Astarte.AppEngine.API.Device.InterfaceValuesOptions.
  """
  def interface_values_options(params \\ [], interface \\ nil) do
    # TODO: generate valid since, since_after, to values
    params gen all since <- constant(nil),
                   since_after <- constant(nil),
                   to <- constant(nil),
                   limit <- optional(integer(1..1000)),
                   downsample_key <- constant(nil),
                   downsample_to <- downsample_to(interface, downsample_key),
                   retrieve_metadata <- optional(boolean()),
                   allow_bigintegers <- optional(boolean()),
                   allow_safe_bigintegers <- optional(boolean()),
                   explicit_timestamp <- optional(boolean()),
                   keep_milliseconds <- optional(boolean()),
                   format <- format(),
                   params: params do
      %{
        since: since,
        since_after: since_after,
        to: to,
        limit: limit,
        downsample_to: downsample_to,
        downsample_key: downsample_key,
        retrieve_metadata: retrieve_metadata,
        allow_bigintegers: allow_bigintegers,
        allow_safe_bigintegers: allow_safe_bigintegers,
        explicit_timestamp: explicit_timestamp,
        keep_milliseconds: keep_milliseconds,
        format: format
      }
    end
  end

  defp optional(gen), do: one_of([nil, gen])
  defp format, do: member_of(["structured", "table", "disjoint_tables"])
  defp downsample_to, do: optional(integer(3..100))
  defp downsample_to(nil = _interface, _), do: nil

  defp downsample_to(interface, _downsample_key) when interface.aggregation == :individual do
    if Device.downsampable?(interface), do: downsample_to()
  end

  defp downsample_to(interface, nil = _downsample_key) when interface.aggregation == :object,
    do: nil

  defp downsample_to(interface, _downsample_key) when interface.aggregation == :object,
    do: downsample_to()
end
