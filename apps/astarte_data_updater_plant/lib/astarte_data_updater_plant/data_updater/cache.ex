#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
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

        Map.size(map) + 1 > size ->
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
