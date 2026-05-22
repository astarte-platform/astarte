#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Adapters.Engine do
  @moduledoc false

  def deep_get(data, []), do: {:ok, data}
  def deep_get(data, path) when is_atom(path) or is_binary(path), do: deep_get(data, [path])
  def deep_get(data, [key]) when is_map(data), do: Map.fetch(data, key)

  def deep_get(data, [key | rest]) when is_map(data) do
    data |> Map.fetch(key) |> continue_get(rest)
  end

  def deep_get(_data, _path), do: :error

  defp continue_get({:ok, data}, rest), do: deep_get(data, rest)
  defp continue_get(:error, _rest), do: :error

  def deep_put(map, path, value) when is_atom(path) or is_binary(path),
    do: deep_put(map, [path], value)

  def deep_put(map, [key], value), do: Map.put(map, key, value)

  def deep_put(map, [key | rest], value) do
    sub_map = ensure_map(Map.get(map, key))
    Map.put(map, key, deep_put(sub_map, rest, value))
  end

  defp ensure_map(val) when is_map(val), do: val
  defp ensure_map(_), do: %{}

  def process_field(
        acc,
        source_map,
        dest_path,
        source_path,
        dest_field_name,
        required,
        custom_fun
      ) do
    source_map
    |> deep_get(source_path)
    |> handle_fetched(
      acc,
      source_map,
      dest_path,
      source_path,
      dest_field_name,
      required,
      custom_fun
    )
  end

  defp handle_fetched(
         :error,
         _acc,
         _source_map,
         _dest_path,
         source_path,
         dest_field_name,
         true,
         _custom_fun
       ) do
    raise Astarte.Adapters.MissingFieldError, field: dest_field_name, path: source_path
  end

  defp handle_fetched(
         :error,
         acc,
         _source_map,
         _dest_path,
         _source_path,
         _dest_field_name,
         false,
         _custom_fun
       ),
       do: acc

  defp handle_fetched(
         {:ok, val},
         acc,
         source_map,
         dest_path,
         _source_path,
         _dest_field_name,
         _req,
         custom_fun
       )
       when is_function(custom_fun, 2) do
    deep_put(acc, dest_path, custom_fun.(val, source_map))
  end

  defp handle_fetched(
         {:ok, _val},
         acc,
         source_map,
         dest_path,
         [],
         _dest_field_name,
         _req,
         custom_fun
       )
       when is_function(custom_fun, 1) do
    deep_put(acc, dest_path, custom_fun.(source_map))
  end

  defp handle_fetched(
         {:ok, val},
         acc,
         _source_map,
         dest_path,
         _source_path,
         _dest_field_name,
         _req,
         custom_fun
       )
       when is_function(custom_fun, 1) do
    deep_put(acc, dest_path, custom_fun.(val))
  end

  defp handle_fetched(
         {:ok, nil},
         _acc,
         _source_map,
         _dest_path,
         source_path,
         dest_field_name,
         true,
         nil
       ) do
    raise Astarte.Adapters.MissingFieldError, field: dest_field_name, path: source_path
  end

  defp handle_fetched(
         {:ok, nil},
         acc,
         _source_map,
         _dest_path,
         _source_path,
         _dest_field_name,
         false,
         nil
       ),
       do: acc

  defp handle_fetched(
         {:ok, val},
         acc,
         _source_map,
         dest_path,
         _source_path,
         _dest_field_name,
         _req,
         nil
       ) do
    deep_put(acc, dest_path, val)
  end

  defp handle_fetched(
         {:ok, _val},
         _acc,
         _source_map,
         _dest_path,
         _source_path,
         dest_field_name,
         _req,
         invalid_custom
       )
       when not is_nil(invalid_custom) do
    received =
      if is_function(invalid_custom) do
        "arity #{:erlang.fun_info(invalid_custom, :arity) |> elem(1)}"
      else
        inspect(invalid_custom)
      end

    raise ArgumentError,
          "Invalid compute function for field #{inspect(dest_field_name)}. Expected arity 1 or 2, got: #{received}"
  end
end
