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
  use ExUnitProperties

  @moduledoc """
  Unix timestamp generator
  """
  @min_default 0
  @max_default 2_556_143_999

  @doc """
  Generates a random timestamp between min and max, defaulting to 0 and 2_556_143_999.
  """
  @type timestamp_opts :: {:min, integer()} | {:max, integer()}
  @spec timestamp([timestamp_opts]) :: StreamData.t(integer())
  def timestamp(opts \\ []) do
    # Cannot use pattern matching, cause it could be in inverse order
    opts = Keyword.validate!(opts, min: @min_default, max: @max_default)
    min = Keyword.fetch!(opts, :min)
    max = Keyword.fetch!(opts, :max)
    timestamp(min, max)
  end

  defp timestamp(min, max) when min < @max_default and max > @min_default and min < max,
    do: integer(min..max)
end
