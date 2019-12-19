#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.TriggerEngine.Templating.StructTemplate do
  alias Astarte.TriggerEngine.Templating.StructTemplate

  defstruct [
    :struct_template
  ]

  def new(struct_template) do
    Map.put(%StructTemplate{}, :struct_template, struct_template)
  end

  def put(template, key, value) do
    Map.put(template, :struct_template, replace_block(template.struct_template, %{key => value}))
  end

  def merge(template, vars) do
    Map.put(template, :struct_template, replace_block(template.struct_template, vars))
  end

  def apply(template) do
    template.struct_template
  end

  defp replace_block(
         %{
           "type" => "astarte.templates.for_each",
           "var" => var_key,
           "current_item_var_name" => current_item_var_name,
           "repeat" => repeat_block
         } = block,
         key_values
       ) do
    if Map.has_key?(key_values, var_key) do
      values_list = Map.fetch!(key_values, var_key)

      for item <- values_list do
        map_with_temp = Map.put(key_values, current_item_var_name, item)

        replace_block(repeat_block, map_with_temp)
      end
    else
      block
    end
  end

  defp replace_block(%{"type" => "astarte.templates.text", "var" => var_key} = block, key_values) do
    if Map.has_key?(key_values, var_key) do
      Map.fetch!(key_values, var_key)
      |> to_string()
    else
      block
    end
  end

  defp replace_block(block, key_values) when is_map(block) do
    Enum.reduce(block, %{}, fn {k, v}, acc ->
      Map.put(acc, k, replace_block(v, key_values))
    end)
  end

  defp replace_block(block, _key_values) do
    block
  end
end
