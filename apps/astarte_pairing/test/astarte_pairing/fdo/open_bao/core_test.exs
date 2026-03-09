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

defmodule Astarte.Pairing.FDO.OpenBao.CoreTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Pairing.FDO.OpenBao
  alias Astarte.Pairing.FDO.OpenBao.Core

  import Astarte.Helpers.OpenBao

  describe "namespace_tokens/3" do
    setup :namespace_tokens_setup

    test "always starts with fdo_owner_keys", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      assert ["fdo_owner_keys" | _] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    test "uses default_instance for empty astarte_instance_id", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      assert [_, "default_instance" | _] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    @tag instance: "someinstance"
    test "uses nested namespaces when instance id is set", context do
      %{
        realm_name: realm_name,
        user_id: user_id,
        key_algorithm: key_algorithm,
        instance: instance
      } = context

      assert [_, "instance", ^instance | _] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    test "places realm name after instance", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      assert [_, _, ^realm_name | _] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    test "uses default_user for empty user id", context do
      %{realm_name: realm_name, key_algorithm: key_algorithm} = context

      assert [_, _, _, "default_user" | _] =
               Core.namespace_tokens(realm_name, nil, key_algorithm)
    end

    @tag user_id: "userid"
    test "uses nested namespaces when user id is set", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      assert [_, _, _, "user_id", ^user_id | _] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    test "ends with key algorithm", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      assert [_, _, _, _, ^key_algorithm] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    @tag instance: "someinstance"
    @tag user_id: "user_id"
    test "produces expected result", context do
      %{
        realm_name: realm_name,
        user_id: user_id,
        key_algorithm: key_algorithm,
        instance: instance
      } = context

      assert [
               "fdo_owner_keys",
               "instance",
               instance,
               realm_name,
               "user_id",
               user_id,
               key_algorithm
             ] == Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end
  end

  describe "create_nested_namespace/1" do
    setup :create_nested_namespace_setup

    test "returns the final namespace created", context do
      %{final_namespace: namespace, tokens: tokens} = context

      assert {:ok, namespace} == Core.create_nested_namespace(tokens)
    end

    test "creates nested namespaces", context do
      %{tokens: tokens, all_namespaces: namespaces} = context
      namespaces = MapSet.new(namespaces)

      {:ok, _} = Core.create_nested_namespace(tokens)
      {:ok, fetched_namespaces} = OpenBao.list_namespaces()
      fetched_namespaces = MapSet.new(fetched_namespaces)

      assert MapSet.subset?(namespaces, fetched_namespaces)
    end
  end

  defp create_nested_namespace_setup(_context) do
    namespace = "some/namespace/path"
    tokens = namespace |> String.split("/", trim: true)
    all_namespaces = ["some/", "some/namespace/", "some/namespace/path/"]

    %{final_namespace: namespace, tokens: tokens, all_namespaces: all_namespaces}
  end
end
