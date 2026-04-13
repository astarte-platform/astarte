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

defmodule Astarte.PairingWeb.ApiSpecTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Astarte.PairingWeb.{ApiSpec, Router}

  test "spec can be generated" do
    spec = ApiSpec.spec()

    assert spec.openapi == "3.0.0"
    assert is_map(spec.paths)
    refute spec.paths == %{}
  end

  test "spec generation emits no missing operation warnings" do
    stderr =
      capture_io(:stderr, fn ->
        ApiSpec.spec()
      end)

    refute stderr =~ "No operation spec defined",
           "OpenAPI spec generation emitted missing operation warnings:\n#{stderr}"
  end

  test "all documented routes are present in the OpenAPI spec" do
    expected_operations =
      Router.__routes__()
      |> MapSet.new(&normalize_route/1)

    actual_operations =
      ApiSpec.spec().paths
      |> Enum.flat_map(fn {path, path_item} ->
        path_item
        |> Map.from_struct()
        |> Enum.filter(fn {_verb, operation} -> not is_nil(operation) end)
        |> Enum.map(fn {verb, _operation} -> {path, verb} end)
      end)
      |> MapSet.new()

    assert MapSet.subset?(expected_operations, actual_operations),
           missing_operations_message(expected_operations, actual_operations)
  end

  defp normalize_route(route) do
    {normalize_path(route.path), normalize_verb(route.verb)}
  end

  defp normalize_path(path) do
    path
    |> String.replace_prefix("/v1", "")
    |> String.split("/", trim: true)
    |> Enum.map_join("/", fn
      <<":", segment::binary>> -> "{" <> segment <> "}"
      segment -> segment
    end)
    |> then(&("/" <> &1))
  end

  defp normalize_verb(verb) when is_atom(verb), do: verb

  defp normalize_verb(verb) when is_binary(verb),
    do: verb |> String.downcase() |> String.to_atom()

  defp missing_operations_message(expected_operations, actual_operations) do
    expected_operations
    |> MapSet.difference(actual_operations)
    |> Enum.sort()
    |> Enum.map_join("\n", fn {path, verb} -> "Missing #{verb} #{path} in OpenAPI spec" end)
  end
end
