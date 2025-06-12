#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Cache do
  @typep cache_size :: non_neg_integer()
  @typep expiry :: integer() | nil

  @type t() :: {cache_size(), %{term => {term(), expiry()}}}
  @type t(key, value) :: {cache_size(), %{key => {value, expiry()}}}

  def new(size) do
    {size, %{}}
  end

  def put({size, map}, key, value, ttl) do
    next_map =
      cond do
        Map.has_key?(map, key) ->
          map

        map_size(map) + 1 > size ->
          {key, _value} = Enum.random(map)
          Map.delete(map, key)

        is_map(map) ->
          map
      end
      |> Map.put(key, {value, expiry_timestamp(ttl)})

    {size, next_map}
  end

  defp expiry_timestamp(nil) do
    nil
  end

  defp expiry_timestamp(ttl) do
    System.system_time(:second) + ttl
  end

  def get(cache, key, default \\ nil) do
    with {:ok, value} <- fetch(cache, key) do
      value
    else
      :error ->
        default
    end
  end

  def fetch({_size, map}, key) do
    with {:ok, {value, expiry}} <- Map.fetch(map, key) do
      if expired?(expiry) do
        :error
      else
        {:ok, value}
      end
    end
  end

  def has_key?({_size, map}, key) do
    case Map.fetch(map, key) do
      {:ok, {_value, expiry}} -> not expired?(expiry)
      :error -> false
    end
  end

  defp expired?(expiry) do
    expiry != nil and expiry <= System.system_time(:second)
  end
end
