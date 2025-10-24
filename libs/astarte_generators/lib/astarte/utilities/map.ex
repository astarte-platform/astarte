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

defmodule Astarte.Utilities.Map do
  @moduledoc """
  Utility macros for extending map functionalities.
  """

  @doc """
  Removes all key-value pairs from a map where the value is `nil`.

  ## Examples

      iex> clean(%{a: 1, b: nil, c: "hello", d: nil})
      %{a: 1, c: "hello"}
  """

  @spec clean(map()) :: map()
  def clean(map) when is_map(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
end
