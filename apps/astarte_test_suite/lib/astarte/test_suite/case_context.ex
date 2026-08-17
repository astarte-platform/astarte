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

defmodule Astarte.TestSuite.CaseContext do
  @moduledoc false

  @loaded_cases_key :astarte_test_suite_loaded_cases
  @fixture_steps_key :astarte_test_suite_fixture_steps
  @graph_collections [
    instances: [parent: nil],
    realms: [parent: :instances],
    interfaces: [parent: :realms],
    devices: [parent: :interfaces],
    groups: [parent: :devices]
  ]

  def put_case(context, case_name, values) when is_map(values) do
    context
    |> Map.merge(values)
    |> append(@loaded_cases_key, case_name)
  end

  def put_fixture(context, fixture_name, values \\ %{}) when is_map(values) do
    context
    |> Map.merge(values)
    |> append(@fixture_steps_key, fixture_name)
  end

  def put(context, key, value), do: {:ok, Map.put(context, key, value)}

  def put(context, key, id, value), do: put(context, key, id, value, nil)
  def put!(context, key, id, value), do: put!(context, key, id, value, nil)

  def put(context, key, id, value, owner_id) do
    key
    |> graph_info()
    |> put_graph(context, key, id, value, owner_id)
  end

  def put!(context, key, value), do: Map.put(context, key, value)

  def put!(context, key, id, value, owner_id) do
    case put(context, key, id, value, owner_id) do
      {:ok, context} -> context
      {:error, reason} -> raise_graph_error!(reason)
    end
  end

  def get(context, key, id) do
    context
    |> Map.get(key, %{})
    |> graph_get(id)
  end

  def get!(context, key, id) do
    case get(context, key, id) do
      nil -> raise_missing_graph_object!(key, id)
      object -> object
    end
  end

  def ids(context, key) do
    context
    |> graph_collection!(key)
    |> Map.keys()
  end

  def reduce(context, key, acc, fun) when is_function(fun, 4) do
    context
    |> graph_collection!(key)
    |> Enum.reduce(acc, fn {id, {value, owner_id}}, inner_acc ->
      fun.(id, value, owner_id, inner_acc)
    end)
  end

  def require_keys!(context, keys, fixture_name) do
    context
    |> missing_keys(keys)
    |> require_keys_result!(context, fixture_name)
  end

  def validate_keyword!(case_name, config, allowed_keys) when is_list(config) do
    case Keyword.keyword?(config) do
      true -> validate_known_keys!(case_name, config, allowed_keys)
      false -> raise_expected_keyword!(case_name, config)
    end
  end

  def validate_keyword!(case_name, config, _allowed_keys),
    do: raise_expected_keyword!(case_name, config)

  def positive_integer?(value) when is_integer(value) and value > 0, do: true
  def positive_integer?(_value), do: false

  def list_of_structs?(values, module) when is_list(values), do: list_of_structs(values, module)
  def list_of_structs?(_values, _module), do: false

  def list_of_binaries?(values) when is_list(values), do: list_of_binaries(values)
  def list_of_binaries?(_values), do: false

  def ensure_binary!(_case_name, _key, value) when is_binary(value), do: value
  def ensure_binary!(case_name, key, _value), do: raise_expected_type!(case_name, key, "a binary")

  def ensure_integer!(_case_name, _key, value) when is_integer(value), do: value

  def ensure_integer!(case_name, key, _value),
    do: raise_expected_type!(case_name, key, "an integer")

  def ensure_boolean!(_case_name, _key, value) when is_boolean(value), do: value

  def ensure_boolean!(case_name, key, _value),
    do: raise_expected_type!(case_name, key, "a boolean")

  def ensure_atom!(_case_name, _key, value) when is_atom(value), do: value

  def ensure_atom!(case_name, key, _value),
    do: raise_expected_type!(case_name, key, "an atom")

  def ensure_positive_integer!(case_name, key, value) do
    case positive_integer?(value) do
      true -> value
      false -> raise_expected_type!(case_name, key, "a positive integer")
    end
  end

  def ensure_member!(case_name, key, value, allowed_values) do
    case member?(value, allowed_values) do
      true -> value
      false -> raise_expected_member!(case_name, key, allowed_values)
    end
  end

  def ensure_list_of_structs!(case_name, key, values, module) do
    case list_of_structs?(values, module) do
      true -> values
      false -> raise_expected_struct_list!(case_name, key, module)
    end
  end

  def ensure_list_of_binaries!(case_name, key, values) do
    case list_of_binaries?(values) do
      true -> values
      false -> raise_expected_type!(case_name, key, "a list of binaries")
    end
  end

  defp graph_info(key), do: Keyword.fetch(@graph_collections, key)

  defp put_graph(:error, _context, key, _id, _value, _owner_id),
    do: {:error, {:unknown_graph_collection, key}}

  defp put_graph({:ok, info}, context, key, id, value, owner_id) do
    info
    |> Keyword.fetch!(:parent)
    |> put_graph_with_parent(context, key, id, value, owner_id)
  end

  defp put_graph_with_parent(nil, context, key, id, value, nil),
    do: put_graph_with_id(context, key, id, value, nil)

  defp put_graph_with_parent(nil, _context, key, _id, _value, owner_id),
    do: {:error, {:unexpected_owner_id, key, owner_id}}

  defp put_graph_with_parent(_parent, _context, key, _id, _value, nil),
    do: {:error, {:missing_owner_id, key}}

  defp put_graph_with_parent(parent, context, key, id, value, owner_id) do
    case owner_exists?(context, parent, owner_id) do
      true -> put_graph_with_id(context, key, id, value, owner_id)
      false -> {:error, {:missing_graph_owner, key, parent, owner_id}}
    end
  end

  defp put_graph_with_id(context, key, id, value, owner_id) do
    case graph_id(id) do
      {:ok, graph_id} -> put_graph_collection(context, key, graph_id, value, owner_id)
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_graph_collection(context, key, id, value, owner_id) do
    collection = Map.get(context, key, %{})

    case Map.fetch(collection, id) do
      {:ok, {_value, ^owner_id}} ->
        {:error, {:graph_collision, key, id}}

      {:ok, {_value, existing_owner_id}} ->
        {:error, {:graph_owner_collision, key, id, existing_owner_id, owner_id}}

      :error ->
        {:ok, Map.put(context, key, Map.put(collection, id, {value, owner_id}))}
    end
  end

  defp owner_exists?(context, parent, owner_id) do
    context
    |> Map.get(parent, %{})
    |> Map.has_key?(owner_id)
  end

  defp graph_get(%{} = collection, id) do
    case Map.fetch(collection, id) do
      {:ok, {object, _owner_id}} -> object
      :error -> nil
    end
  end

  defp graph_get(_collection, _id), do: nil

  defp graph_collection!(context, key) do
    case Map.fetch(context, key) do
      {:ok, %{} = collection} -> collection
      {:ok, _collection} -> raise_invalid_graph_collection!(key)
      :error -> raise_missing_graph_collection!(key)
    end
  end

  defp graph_id(id) when is_binary(id), do: {:ok, id}
  defp graph_id(_id), do: {:error, :invalid_graph_id}

  defp validate_known_keys!(case_name, config, allowed_keys) do
    case unknown_keys(Keyword.keys(config), allowed_keys) do
      [] -> config
      unknown_keys -> raise_unknown_keys!(case_name, unknown_keys, allowed_keys)
    end
  end

  defp missing_keys(context, keys) do
    Enum.reject(keys, &Map.has_key?(context, &1))
  end

  defp require_keys_result!([], context, _fixture_name), do: context

  defp require_keys_result!(missing_keys, _context, fixture_name) do
    raise ArgumentError,
          "#{inspect(fixture_name)} requires context keys #{inspect(missing_keys)}"
  end

  defp unknown_keys(keys, allowed_keys) do
    Enum.reject(keys, &member?(&1, allowed_keys))
  end

  defp list_of_structs([], _module), do: true

  defp list_of_structs([%{__struct__: module} | rest], module),
    do: list_of_structs(rest, module)

  defp list_of_structs([_value | _rest], _module), do: false

  defp list_of_binaries([]), do: true
  defp list_of_binaries([value | rest]) when is_binary(value), do: list_of_binaries(rest)
  defp list_of_binaries([_value | _rest]), do: false

  defp member?(_value, []), do: false
  defp member?(value, [value | _rest]), do: true
  defp member?(value, [_head | rest]), do: member?(value, rest)

  defp append(context, key, value) do
    Map.update(context, key, [value], &(&1 ++ [value]))
  end

  defp raise_expected_keyword!(case_name, config) do
    raise ArgumentError,
          "#{inspect(case_name)} expects a keyword list configuration, got #{inspect(config)}"
  end

  defp raise_unknown_keys!(case_name, unknown_keys, allowed_keys) do
    raise ArgumentError,
          "#{inspect(case_name)} received unknown configuration keys " <>
            "#{inspect(unknown_keys)}. Allowed keys are #{inspect(allowed_keys)}"
  end

  defp raise_expected_type!(case_name, key, type) do
    raise ArgumentError, "#{inspect(case_name)} expects #{inspect(key)} to be #{type}"
  end

  defp raise_expected_member!(case_name, key, allowed_values) do
    raise ArgumentError,
          "#{inspect(case_name)} expects #{inspect(key)} to be one of #{inspect(allowed_values)}"
  end

  defp raise_expected_struct_list!(case_name, key, module) do
    raise ArgumentError,
          "#{inspect(case_name)} expects #{inspect(key)} to be a list of #{inspect(module)} structs"
  end

  defp raise_missing_graph_object!(key, id) do
    raise ArgumentError, "missing #{inspect(key)} graph object with id #{inspect(id)}"
  end

  defp raise_graph_error!({:unknown_graph_collection, key}) do
    raise ArgumentError, "unknown graph collection #{inspect(key)}"
  end

  defp raise_graph_error!({:missing_owner_id, key}) do
    raise ArgumentError, "#{inspect(key)} expects an owner_id positional argument"
  end

  defp raise_graph_error!({:unexpected_owner_id, key, owner_id}) do
    raise ArgumentError, "#{inspect(key)} does not accept owner_id #{inspect(owner_id)}"
  end

  defp raise_graph_error!({:missing_graph_owner, key, parent, owner_id}) do
    raise ArgumentError,
          "#{inspect(key)} has no #{inspect(parent)} graph owner with id #{inspect(owner_id)}"
  end

  defp raise_graph_error!({:graph_collision, key, id}) do
    raise ArgumentError, "#{inspect(key)} graph object already exists with id #{inspect(id)}"
  end

  defp raise_graph_error!({:graph_owner_collision, key, id, existing_owner_id, owner_id}) do
    raise ArgumentError,
          "#{inspect(key)} graph object id #{inspect(id)} already belongs to " <>
            "#{inspect(existing_owner_id)}, got #{inspect(owner_id)}"
  end

  defp raise_graph_error!(:invalid_graph_id),
    do: raise(ArgumentError, "graph id must be a binary")

  defp raise_missing_graph_collection!(key) do
    raise ArgumentError, "missing canonical graph collection #{inspect(key)}"
  end

  defp raise_invalid_graph_collection!(key) do
    raise ArgumentError, "#{inspect(key)} is not a canonical graph collection"
  end
end
