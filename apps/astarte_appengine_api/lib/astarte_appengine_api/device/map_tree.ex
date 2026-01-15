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
      value_map = build_tree_from_path(key, value)

      merge_tree(acc, value_map)
    end)
  end

  defp build_tree_from_path(path, value) do
    tokens = String.split(path, "/")

    put_in(%{}, Enum.map(tokens, &Access.key(&1, %{})), value)
  end

  defp merge_tree(existing_tree, new_map) do
    Map.merge(existing_tree, new_map, fn
      _k, existing_submap, new_submap when is_map(existing_submap) and is_map(new_submap) ->
        merge_tree(existing_submap, new_submap)
    end)
  end
end
