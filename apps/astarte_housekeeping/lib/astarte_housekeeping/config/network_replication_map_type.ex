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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.Housekeeping.Config.NetworkReplicationMap do
  @moduledoc """
  The network replication map for a scylladb keyspace, a map of non-empty strings to positive integers
  """
  use Skogsra.Type

  @impl Skogsra.Type
  def cast(value)

  def cast(value) when is_binary(value) do
    with {:ok, map} <- Jason.decode(value),
         true <- is_map(map),
         true <- Enum.all?(map, fn {k, v} -> nonempty_string?(k) && positive_integer?(v) end) do
      {:ok, map}
    else
      _ -> :error
    end
  end

  def cast(_) do
    :error
  end

  defp nonempty_string?(string) when is_binary(string), do: String.length(string) > 0
  defp nonempty_string?(_other), do: false
  defp positive_integer?(integer) when is_integer(integer), do: integer > 0
  defp positive_integer?(_other), do: false
end
