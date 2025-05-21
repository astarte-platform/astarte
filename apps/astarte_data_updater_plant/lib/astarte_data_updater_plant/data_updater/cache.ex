#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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
      if is_expired?(expiry) do
        {:ok, value}
      else
        :error
      end
    end
  end

  def has_key?({_size, map}, key) do
    with {:ok, {_value, expiry}} <- Map.fetch(map, key) do
      not is_expired?(expiry)
    else
      :error ->
        false
    end
  end

  defp is_expired?(expiry) do
    expiry == nil or expiry > System.system_time(:second)
  end
end
