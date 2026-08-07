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

defmodule Astarte.TestSuite.Helpers.RealmTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Helpers.Instance, as: InstanceHelper
  alias Astarte.TestSuite.Helpers.Realm, as: RealmHelper

  @tag :real_db
  test "realm helper sets realms flag" do
    assert context().realms_ready?
  end

  @tag :real_db
  test "realm helper creates keyspaces for each instance and realm" do
    assert context().realm_keyspaces |> length() == 1
  end

  @tag :real_db
  test "realm helper creates database statements for each realm" do
    assert context().realm_database_statements |> length() == 20
  end

  @tag :real_db
  test "realm helper creates realm keyspace SQL" do
    context = context()

    assert context.realm_database_statements |> hd() =~
             "CREATE KEYSPACE IF NOT EXISTS #{hd(context.realm_keyspaces)}"
  end

  @tag :real_db
  test "realm helper inserts realm into the instance keyspace" do
    context = context()

    assert Enum.at(context.realm_database_statements, 1) =~
             "INSERT INTO #{hd(context.realm_keyspaces)}.realms"
  end

  @tag :real_db
  test "realm helper creates devices table SQL" do
    context = context()

    assert Enum.at(context.realm_database_statements, 2) =~
             "CREATE TABLE IF NOT EXISTS #{hd(context.realm_keyspaces)}.devices"
  end

  @tag :real_db
  test "realm helper creates interfaces table SQL" do
    context = context()

    assert Enum.at(context.realm_database_statements, 9) =~
             "CREATE TABLE IF NOT EXISTS #{hd(context.realm_keyspaces)}.interfaces"
  end

  test "realm helper creates canonical graph realms" do
    assert RealmHelper.realms(realm_context()).realms == %{
             "realm1" => {%{id: "realm1", name: "realm1", instance_id: "astarte1"}, "astarte1"},
             "realm2" => {%{id: "realm2", name: "realm2", instance_id: "astarte1"}, "astarte1"}
           }
  end

  test "realm helper creates names for every instance" do
    assert RealmHelper.realm_names(%{
             realm_number: 2,
             instances: %{"a" => {"a", nil}, "b" => {"b", nil}}
           })
           |> length() == 4
  end

  test "realm helper distributes realm names across instances" do
    assert RealmHelper.realms(multi_instance_realm_context()).realms == %{
             "realm1" => {%{id: "realm1", name: "realm1", instance_id: "astarte1"}, "astarte1"},
             "realm2" => {%{id: "realm2", name: "realm2", instance_id: "astarte2"}, "astarte2"}
           }
  end

  test "realm helper ignores missing realm names for remaining instances" do
    assert RealmHelper.realms(partial_realm_context()).realms == %{
             "realm1" => {%{id: "realm1", name: "realm1", instance_id: "astarte1"}, "astarte1"}
           }
  end

  defp context do
    instance_id = unique_instance_id()
    [first_realm, second_realm] = unique_realm_ids()

    %{
      instance_cluster: :xandra,
      instances: %{instance_id => {instance_id, nil}}
    }
    |> InstanceHelper.setup()
    |> InstanceHelper.data()
    |> Map.merge(%{
      instance_database_ready?: true,
      realms: %{
        first_realm => {%{id: first_realm, instance_id: instance_id}, instance_id},
        second_realm => {%{id: second_realm, instance_id: instance_id}, instance_id}
      }
    })
    |> RealmHelper.data()
  end

  defp realm_context do
    %{instances: %{"astarte1" => {"astarte1", nil}}, realm_names: ["realm1", "realm2"]}
  end

  defp multi_instance_realm_context do
    %{
      instances: %{
        "astarte1" => {"astarte1", nil},
        "astarte2" => {"astarte2", nil}
      },
      realm_names: ["realm1", "realm2"],
      realm_number: 1
    }
  end

  defp partial_realm_context do
    %{
      instances: %{
        "astarte1" => {"astarte1", nil},
        "astarte2" => {"astarte2", nil}
      },
      realm_names: ["realm1"],
      realm_number: 1
    }
  end

  defp unique_instance_id do
    "astarte" <> Integer.to_string(System.unique_integer([:positive]))
  end

  defp unique_realm_ids do
    [
      "realm" <> Integer.to_string(System.unique_integer([:positive])),
      "realm" <> Integer.to_string(System.unique_integer([:positive]))
    ]
  end
end
