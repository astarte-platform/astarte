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

  def put({size, map}, key, value) do
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
      |> Map.put(key, value)

    {size, next_map}
  end

  def get({_size, map}, key, default \\ nil) do
    Map.get(map, key, default)
  end

  def fetch({_size, map}, key) do
    Map.fetch(map, key)
  end

  def has_key?({_size, map}, key) do
    Map.has_key?(map, key)
  end
end
