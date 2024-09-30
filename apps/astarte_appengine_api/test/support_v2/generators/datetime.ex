#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.Test.Generators.DateTime do
  use ExUnitProperties

  @min_default 0
  @max_default 2_556_143_999

  def date_time!(opts \\ []) do
    [min: min, max: max] = Keyword.validate!(opts, min: @min_default, max: @max_default)
    date_time!(min, max)
  end

  defp date_time!(min, max) when min < max, do: integer(min..max) |> map(&DateTime.from_unix!(&1))
  defp date_time!(min, max), do: raise("Datetime generator, received min: #{min} >= max: #{max}")
end
