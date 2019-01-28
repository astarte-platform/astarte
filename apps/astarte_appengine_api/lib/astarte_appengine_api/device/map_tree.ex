#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Device.MapTree do
  @spec inflate_tree(map) :: map
  def inflate_tree(values_map) do
    Enum.reduce(values_map, %{}, fn {key, value}, acc ->
      new_value =
        if String.contains?(key, "/") do
          build_tree_from_path(key, value)
        else
          %{key => value}
        end

      merge_tree(acc, new_value)
    end)
  end

  defp build_tree_from_path(path, value) do
    tokens = String.split(path, "/")

    List.foldr(tokens, value, fn token, subtree ->
      %{token => subtree}
    end)
  end

  defp merge_tree(existing_tree, new_tree) do
    {subkey, subtree} = Enum.at(new_tree, 0)

    cond do
      Map.get(existing_tree, subkey) == nil ->
        Map.put(existing_tree, subkey, subtree)

      is_map(subtree) ->
        Map.put(existing_tree, subkey, merge_tree(Map.get(existing_tree, subkey), subtree))

      true ->
        Map.put(existing_tree, subkey, subtree)
    end
  end
end
