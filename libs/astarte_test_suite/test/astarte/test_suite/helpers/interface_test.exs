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

defmodule Astarte.TestSuite.Helpers.InterfaceTest do
  use ExUnit.Case, async: false

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Interface

  alias Astarte.TestSuite.Helpers.Instance, as: InstanceHelper
  alias Astarte.TestSuite.Helpers.Interface, as: InterfaceHelper
  alias Astarte.TestSuite.Helpers.Realm, as: RealmHelper

  import Astarte.Core.Generators.Interface, only: [interface: 0]

  test "interface helper creates canonical graph interfaces" do
    assert InterfaceHelper.interfaces(graph_context()).interfaces
           |> Map.values()
           |> hd()
           |> elem(1) == "realm1"
  end

  test "interface helper creates core interface entries" do
    assert InterfaceHelper.interfaces(graph_context())
           |> Map.fetch!(:interfaces)
           |> Map.values()
           |> hd()
           |> elem(0)
           |> is_struct(Interface)
  end

  test "interface helper raises when interface realm owner is missing" do
    assert_raise ArgumentError, ~r/missing :realms graph object with id "missing"/, fn ->
      missing_realm_context()
    end
  end

  @tag :real_db
  test "interface helper sets registration flag after real persistence" do
    assert persisted_context().interfaces_registered?
  end

  @tag :real_db
  test "interface helper records one keyspace result after real persistence" do
    context = persisted_context()

    assert context.interface_database_results
           |> hd()
           |> Map.fetch!(:keyspace) == context.instances |> Map.keys() |> hd()
  end

  @tag :real_db
  test "interface helper raises when interface persistence fails" do
    assert_raise RuntimeError, ~r/failed to insert interfaces into missing/, fn ->
      failing_persisted_context()
    end
  end

  defp persisted_context do
    persisted_graph_context()
    |> InterfaceHelper.data()
  end

  defp missing_realm_context do
    interface = core_interface()

    %{realms: %{}, interfaces: %{interface.name => {interface, "missing"}}}
    |> InterfaceHelper.data()
  end

  defp failing_persisted_context do
    interface = core_interface()

    %{
      realms: %{"realm1" => {%{id: "realm1", instance_id: "missing"}, "missing"}},
      interfaces: %{interface.name => {interface, "realm1"}}
    }
    |> InterfaceHelper.data()
  end

  defp graph_context do
    %{}
    |> put!(:instances, "astarte1", "astarte1", nil)
    |> put!(:realms, "realm1", %{id: "realm1", instance_id: "astarte1"}, "astarte1")
    |> Map.put(:interface_number, 1)
  end

  defp persisted_graph_context do
    instance_id = "astarte" <> Integer.to_string(System.unique_integer([:positive]))
    realm_id = "realm" <> Integer.to_string(System.unique_integer([:positive]))

    %{
      instance_cluster: :xandra,
      instances: %{instance_id => {instance_id, nil}},
      realms: %{realm_id => {%{id: realm_id, instance_id: instance_id}, instance_id}}
    }
    |> InstanceHelper.setup()
    |> InstanceHelper.data()
    |> RealmHelper.data()
    |> put!(:interfaces, core_interface().name, core_interface(), realm_id)
  end

  defp core_interface, do: interface() |> Enum.at(0)
end
