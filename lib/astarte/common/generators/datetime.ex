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

defmodule Astarte.Common.Generators.DateTime do
  @moduledoc """
  DateTime generator
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Common.Generators.Timestamp, as: TimestampGenerator

  @doc false
  @spec min_default :: DateTime.t()
  def min_default, do: TimestampGenerator.min_default() |> DateTime.from_unix!(:microsecond)

  @doc false
  @spec max_default :: DateTime.t()
  def max_default, do: TimestampGenerator.max_default() |> DateTime.from_unix!(:microsecond)

  @doc """
  Generates a random DateTime from min to max (see Timestamp generator)
  """
  @spec date_time() :: StreamData.t(DateTime.t())
  @spec date_time(params :: keyword()) :: StreamData.t(DateTime.t())
  def date_time(params \\ []) do
    config =
      params gen all min <- constant(min_default()),
                     max <- constant(max_default()),
                     params: params do
        {DateTime.to_unix(min, :microsecond), DateTime.to_unix(max, :microsecond)}
      end

    gen all {min, max} <- config,
            date_time <-
              TimestampGenerator.timestamp(min: min, max: max)
              |> map(&DateTime.from_unix!(&1, :microsecond)) do
      date_time
    end
  end
end
