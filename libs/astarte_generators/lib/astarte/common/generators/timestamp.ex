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

defmodule Astarte.Common.Generators.Timestamp do
  @moduledoc """
  Unix timestamp generator
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  @min_default 0
  @max_default 2_556_143_999_999_999

  @ref_unit :microsecond
  @default_unit :second

  @doc false
  @spec min_default() :: integer()
  @spec min_default(unit :: atom()) :: integer()
  def min_default(unit \\ @default_unit),
    do: @min_default |> System.convert_time_unit(@ref_unit, unit)

  @doc false
  @spec max_default() :: integer()
  @spec max_default(unit :: atom()) :: integer()
  def max_default(unit \\ @default_unit),
    do: @max_default |> System.convert_time_unit(@ref_unit, unit)

  @doc """
  Generates a random timestamp between min and max, defaulting to 0 and 2_556_143_999_999_999 (µs).
  """
  @spec timestamp() :: StreamData.t(integer())
  @spec timestamp(params :: keyword()) :: StreamData.t(integer())
  def timestamp(params \\ []) do
    params gen all unit <- constant(@default_unit),
                   min <- constant(min_default(unit)),
                   max <- constant(max_default(unit)),
                   timestamp <- timestamp(min, max),
                   params: params,
                   exclude: [:timestamp] do
      timestamp
    end
  end

  defp timestamp(min, max) when min < @max_default and max > @min_default and min < max,
    do: integer(min..max)
end
