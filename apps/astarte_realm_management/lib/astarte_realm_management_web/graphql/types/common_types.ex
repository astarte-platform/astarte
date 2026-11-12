#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.RealmManagementWeb.GraphQL.Types.CommonTypes do
  @moduledoc false
  use Absinthe.Schema.Notation

  @desc "A custom scalar representing arbitrary JSON data (passed as a map in variables)"
  scalar :json, open_ended: true do
    parse(&parse_json/1)

    serialize(fn value ->
      value
    end)
  end

  defp parse_json(%Absinthe.Blueprint.Input.Object{fields: fields}) do
    Enum.reduce_while(fields, {:ok, %{}}, fn %Absinthe.Blueprint.Input.Field{
                                               name: name,
                                               input_value: input_value
                                             },
                                             {:ok, acc} ->
      case parse_json(input_value.normalized) do
        {:ok, parsed_value} -> {:cont, {:ok, Map.put(acc, to_string(name), parsed_value)}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp parse_json(%Absinthe.Blueprint.Input.List{items: items}) do
    Enum.reduce_while(items, {:ok, []}, fn %Absinthe.Blueprint.Input.Value{normalized: normalized},
                                           {:ok, acc} ->
      case parse_json(normalized) do
        {:ok, parsed_value} -> {:cont, {:ok, [parsed_value | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      :error -> :error
    end
  end

  defp parse_json(%Absinthe.Blueprint.Input.String{value: value}), do: {:ok, value}
  defp parse_json(%Absinthe.Blueprint.Input.Integer{value: value}), do: {:ok, value}
  defp parse_json(%Absinthe.Blueprint.Input.Float{value: value}), do: {:ok, value}
  defp parse_json(%Absinthe.Blueprint.Input.Boolean{value: value}), do: {:ok, value}
  defp parse_json(%Absinthe.Blueprint.Input.Null{}), do: {:ok, nil}
  defp parse_json(%Absinthe.Blueprint.Input.RawValue{content: content}), do: parse_json(content)

  defp parse_json(map) when is_map(map) and not is_struct(map) do
    Enum.reduce_while(map, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      case parse_json(v) do
        {:ok, parsed_value} -> {:cont, {:ok, Map.put(acc, to_string(k), parsed_value)}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp parse_json(list) when is_list(list) do
    Enum.reduce_while(list, {:ok, []}, fn v, {:ok, acc} ->
      case parse_json(v) do
        {:ok, parsed_value} -> {:cont, {:ok, [parsed_value | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, reversed_list} -> {:ok, Enum.reverse(reversed_list)}
      :error -> :error
    end
  end

  defp parse_json(value) when not is_struct(value), do: {:ok, value}
  defp parse_json(_), do: :error
end
