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

defmodule Astarte.TestSuite.CaseContextTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Interface

  test "put_case writes realm name" do
    assert case_context().realm_name == "realm"
  end

  test "put_case writes instance name" do
    assert case_context().instance_name == "instance"
  end

  test "put_case tracks loaded cases" do
    assert case_context().astarte_test_suite_loaded_cases == [:common, :instance]
  end

  test "put_fixture writes values" do
    assert fixture_context().ready?
  end

  test "put_fixture tracks fixture steps" do
    assert fixture_context().astarte_test_suite_fixture_steps == [:setup, :realm]
  end

  test "require_keys returns context when all keys exist" do
    assert require_keys!(%{ready?: true}, [:ready?], :fixture) == %{ready?: true}
  end

  test "require_keys raises when a key is missing" do
    assert_raise ArgumentError, ~r/:fixture requires context keys \[:missing\]/, fn ->
      require_keys!(%{}, [:missing], :fixture)
    end
  end

  test "validate_keyword returns valid keyword configuration" do
    assert validate_keyword!(:case_name, [value: 1], [:value]) == [value: 1]
  end

  test "validate_keyword rejects unknown keys" do
    assert_raise ArgumentError, ~r/unknown configuration keys \[:unknown\]/, fn ->
      validate_keyword!(:case_name, [unknown: true], [:value])
    end
  end

  test "validate_keyword rejects non keyword lists" do
    assert_raise ArgumentError, ~r/expects a keyword list configuration/, fn ->
      validate_keyword!(:case_name, [:value], [:value])
    end
  end

  test "validate_keyword rejects non lists" do
    assert_raise ArgumentError, ~r/expects a keyword list configuration/, fn ->
      validate_keyword!(:case_name, :value, [:value])
    end
  end

  test "positive_integer? accepts positive integers" do
    assert positive_integer?(1)
  end

  test "positive_integer? rejects zero" do
    refute positive_integer?(0)
  end

  test "positive_integer? rejects binaries" do
    refute positive_integer?("1")
  end

  test "list_of_structs? accepts struct lists" do
    assert list_of_structs?([%Interface{}], Interface)
  end

  test "list_of_structs? rejects map lists" do
    refute list_of_structs?([%{}], Interface)
  end

  test "list_of_structs? rejects non lists" do
    refute list_of_structs?(:interface, Interface)
  end

  test "list_of_binaries? accepts binary lists" do
    assert list_of_binaries?(["a", "b"])
  end

  test "list_of_binaries? rejects mixed lists" do
    refute list_of_binaries?(["a", 1])
  end

  test "list_of_binaries? rejects non lists" do
    refute list_of_binaries?(:values)
  end

  test "ensures binary values" do
    assert ensure_binary!(:case_name, :name, "value") == "value"
  end

  test "ensures integer values" do
    assert ensure_integer!(:case_name, :count, 3) == 3
  end

  test "ensures boolean values" do
    assert ensure_boolean!(:case_name, :enabled, true)
  end

  test "ensures atom values" do
    assert ensure_atom!(:case_name, :cluster, :xandra) == :xandra
  end

  test "ensures positive integer values" do
    assert ensure_positive_integer!(:case_name, :port, 1) == 1
  end

  test "rejects invalid binary values" do
    assert_raise ArgumentError, ~r/expects :name to be a binary/, fn ->
      ensure_binary!(:case_name, :name, 1)
    end
  end

  test "rejects invalid integer values" do
    assert_raise ArgumentError, ~r/expects :count to be an integer/, fn ->
      ensure_integer!(:case_name, :count, "3")
    end
  end

  test "rejects invalid boolean values" do
    assert_raise ArgumentError, ~r/expects :enabled to be a boolean/, fn ->
      ensure_boolean!(:case_name, :enabled, "true")
    end
  end

  test "rejects invalid atom values" do
    assert_raise ArgumentError, ~r/expects :cluster to be an atom/, fn ->
      ensure_atom!(:case_name, :cluster, "xandra")
    end
  end

  test "rejects invalid positive integer values" do
    assert_raise ArgumentError, ~r/expects :port to be a positive integer/, fn ->
      ensure_positive_integer!(:case_name, :port, 0)
    end
  end

  test "ensures member values" do
    assert ensure_member!(:case_name, :transport, :mqtt, [:mqtt, :http]) == :mqtt
  end

  test "ensures lists of structs" do
    assert ensure_list_of_structs!(:case_name, :interfaces, [%Interface{}], Interface) ==
             [
               %Interface{}
             ]
  end

  test "ensures lists of binaries" do
    assert ensure_list_of_binaries!(:case_name, :scopes, ["realm"]) == ["realm"]
  end

  test "rejects invalid member values" do
    assert_raise ArgumentError, ~r/expects :transport to be one of \[:mqtt, :http\]/, fn ->
      ensure_member!(:case_name, :transport, :amqp, [:mqtt, :http])
    end
  end

  test "rejects invalid lists of structs" do
    assert_raise ArgumentError, ~r/expects :interfaces to be a list/, fn ->
      ensure_list_of_structs!(:case_name, :interfaces, [%{}], Interface)
    end
  end

  test "rejects invalid lists of binaries" do
    assert_raise ArgumentError, ~r/expects :scopes to be a list of binaries/, fn ->
      ensure_list_of_binaries!(:case_name, :scopes, [:realm])
    end
  end

  test "put stores plain values" do
    assert put!(%{}, :instance_cluster, :xandra).instance_cluster == :xandra
  end

  test "put returns tagged context" do
    assert put(%{}, :instance_cluster, :xandra) == {:ok, %{instance_cluster: :xandra}}
  end

  test "put with four arguments defaults owner_id to nil for root graph collections" do
    assert put(%{}, :instances, "astarte1", "astarte1") ==
             {:ok, %{instances: %{"astarte1" => {"astarte1", nil}}}}
  end

  test "put! with four arguments defaults owner_id to nil for root graph collections" do
    assert put!(%{}, :instances, "astarte1", "astarte1") ==
             %{instances: %{"astarte1" => {"astarte1", nil}}}
  end

  test "put stores graph values in canonical maps" do
    assert graph_context().interfaces == %{
             "interface" => {%Interface{name: "interface"}, "realm1"}
           }
  end

  test "get returns graph objects by collection and id" do
    assert get(graph_context(), :interfaces, "interface") == %Interface{
             name: "interface"
           }
  end

  test "get returns nil for missing graph ids" do
    assert get(graph_context(), :interfaces, "missing") == nil
  end

  test "get returns nil for unknown graph collections" do
    assert get(graph_context(), :unknown, "interface") == nil
  end

  test "get returns nil for non canonical graph collections" do
    assert get(%{interfaces: []}, :interfaces, "interface") == nil
  end

  test "get! returns graph objects by collection and id" do
    assert get!(graph_context(), :realms, "realm1") == %{id: "realm1"}
  end

  test "ids returns graph ids from canonical collections" do
    assert ids(graph_context(), :interfaces) == ["interface"]
  end

  test "reduce iterates canonical graph collections centrally" do
    assert reduce(graph_context(), :interfaces, [], fn id, value, owner_id, acc ->
             acc ++ [{id, value.name, owner_id}]
           end) == [{"interface", "interface", "realm1"}]
  end

  test "ids raises for missing canonical collections" do
    assert_raise ArgumentError, ~r/missing canonical graph collection :interfaces/, fn ->
      ids(%{}, :interfaces)
    end
  end

  test "reduce raises for non canonical collections" do
    assert_raise ArgumentError, ~r/:interfaces is not a canonical graph collection/, fn ->
      reduce(%{interfaces: []}, :interfaces, [], fn _id, _value, _owner_id, acc -> acc end)
    end
  end

  test "get! raises for missing graph objects" do
    assert_raise ArgumentError, ~r/missing :interfaces graph object/, fn ->
      get!(graph_context(), :interfaces, "missing")
    end
  end

  test "put rejects unknown graph collections" do
    assert put(%{}, :unknown, "id", %{}, nil) ==
             {:error, {:unknown_graph_collection, :unknown}}
  end

  test "put rejects owners on root graph collections with arbitrary values" do
    assert put(%{}, :instances, "astarte1", "astarte1", :bad) ==
             {:error, {:unexpected_owner_id, :instances, :bad}}
  end

  test "put rejects nil owner ids for owned graph collections" do
    assert put(%{}, :realms, "realm1", %{id: "realm1"}, nil) ==
             {:error, {:missing_owner_id, :realms}}
  end

  test "put rejects owners on root graph collections" do
    assert put(%{}, :instances, "astarte1", "astarte1", "owner") ==
             {:error, {:unexpected_owner_id, :instances, "owner"}}
  end

  test "put rejects missing owners" do
    assert put(%{}, :realms, "realm1", %{id: "realm1"}, "astarte1") ==
             {:error, {:missing_graph_owner, :realms, :instances, "astarte1"}}
  end

  test "put rejects duplicate graph ids" do
    assert put(graph_context(), :interfaces, "interface", %Interface{name: "interface"}, "realm1") ==
             {:error, {:graph_collision, :interfaces, "interface"}}
  end

  test "put rejects duplicate graph ids under different owners" do
    assert put(
             inconsistent_owner_context(),
             :interfaces,
             "interface",
             %Interface{
               name: "interface"
             },
             "realm2"
           ) == {:error, {:graph_owner_collision, :interfaces, "interface", "realm1", "realm2"}}
  end

  test "put rejects non binary ids" do
    assert put(%{}, :instances, :astarte1, "astarte1", nil) ==
             {:error, :invalid_graph_id}
  end

  test "put accepts explicit instance ids" do
    assert put!(%{}, :instances, "astarte1", "astarte1", nil).instances ==
             %{"astarte1" => {"astarte1", nil}}
  end

  test "put accepts realm values with explicit ids" do
    assert put!(instance_context(), :realms, "realm1", %{name: "realm1"}, "astarte1").realms ==
             %{"realm1" => {%{name: "realm1"}, "astarte1"}}
  end

  test "put accepts realm binaries with explicit ids" do
    assert put!(instance_context(), :realms, "realm1", "realm1", "astarte1").realms ==
             %{"realm1" => {"realm1", "astarte1"}}
  end

  test "put accepts group objects with id ids" do
    assert put!(
             device_context(),
             :groups,
             "group1",
             %{id: "group1"},
             "device"
           ).groups == %{"group1" => {%{id: "group1"}, "device"}}
  end

  test "put accepts group objects with name ids" do
    assert put!(
             device_context(),
             :groups,
             "group1",
             %{name: "group1"},
             "device"
           ).groups == %{"group1" => {%{name: "group1"}, "device"}}
  end

  test "put! raises graph errors" do
    assert_raise ArgumentError, ~r/unknown graph collection/, fn ->
      put!(%{}, :unknown, "id", %{}, nil)
    end
  end

  test "put! raises unexpected owner errors" do
    assert_raise ArgumentError, ~r/does not accept owner_id/, fn ->
      put!(%{}, :instances, "astarte1", "astarte1", "owner")
    end
  end

  test "put! raises missing owner errors" do
    assert_raise ArgumentError, ~r/has no :instances graph owner/, fn ->
      put!(%{}, :realms, "realm1", %{id: "realm1"}, "astarte1")
    end
  end

  test "put! with four arguments raises when an owned graph collection misses owner_id" do
    assert_raise ArgumentError, ~r/expects an owner_id positional argument/, fn ->
      put!(%{}, :realms, "realm1", %{id: "realm1"})
    end
  end

  test "put! raises duplicate id errors" do
    assert_raise ArgumentError, ~r/graph object already exists/, fn ->
      put!(graph_context(), :interfaces, "interface", %Interface{name: "interface"}, "realm1")
    end
  end

  test "put! raises inconsistent ownership errors" do
    assert_raise ArgumentError, ~r/already belongs to/, fn ->
      put!(
        inconsistent_owner_context(),
        :interfaces,
        "interface",
        %Interface{name: "interface"},
        "realm2"
      )
    end
  end

  test "put! raises invalid graph id errors" do
    assert_raise ArgumentError, ~r/graph id must be a binary/, fn ->
      put!(%{}, :instances, :astarte1, "astarte1", nil)
    end
  end

  defp case_context do
    %{}
    |> put_case(:common, %{realm_name: "realm"})
    |> put_case(:instance, %{instance_name: "instance"})
  end

  defp fixture_context do
    %{}
    |> put_fixture(:setup)
    |> put_fixture(:realm, %{ready?: true})
  end

  defp graph_context do
    %{}
    |> put!(:instances, "astarte1", "astarte1", nil)
    |> put!(:realms, "realm1", %{id: "realm1"}, "astarte1")
    |> put!(:interfaces, "interface", %Interface{name: "interface"}, "realm1")
  end

  defp instance_context do
    %{}
    |> put!(:instances, "astarte1", "astarte1", nil)
  end

  defp device_context do
    graph_context()
    |> put!(:devices, "device", %{name: "device"}, "interface")
  end

  defp inconsistent_owner_context do
    graph_context()
    |> put!(:realms, "realm2", %{id: "realm2"}, "astarte1")
  end
end
