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

defmodule Astarte.Common.Generators.DateTime do
  @moduledoc """
  DateTime generator
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Common.Generators.Timestamp

  @ref_unit :microsecond

  @doc false
  @spec date_time_min_default :: DateTime.t()
  def date_time_min_default,
    do: timestamp_min_default(@ref_unit) |> DateTime.from_unix!(@ref_unit)

  @doc false
  @spec date_time_max_default :: DateTime.t()
  def date_time_max_default,
    do: timestamp_max_default(@ref_unit) |> DateTime.from_unix!(@ref_unit)

  @doc """
  Generates a random DateTime from min to max (see Timestamp generator)
  """
  @spec date_time() :: StreamData.t(DateTime.t())
  @spec date_time(params :: keyword()) :: StreamData.t(DateTime.t())
  def date_time(params \\ []) do
    params gen all min <- constant(date_time_min_default()),
                   max <- constant(date_time_max_default()),
                   min = DateTime.to_unix(min, @ref_unit),
                   max = DateTime.to_unix(max, @ref_unit),
                   date_time <-
                     timestamp(min: min, max: max, unit: @ref_unit)
                     |> map(&DateTime.from_unix!(&1, @ref_unit)),
                   params: params,
                   exclude: [:date_time] do
      date_time
    end
  end
end
