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

defmodule Astarte.TestSuite.Helpers.RealmTest do
  use ExUnit.Case, async: true

  import Astarte.Core.Realm, only: [valid_name?: 1]

  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Realms.Realm, as: RealmData

  alias Astarte.TestSuite.Helpers.Instance, as: InstanceHelper
  alias Astarte.TestSuite.Helpers.Realm, as: RealmHelper

  describe "data/1" do
    @tag :integration
    test "persists and migrates every realm" do
      context = context()
      realm_names = Map.keys(context.realms)

      assert context.realms_ready?
      assert length(context.realm_keyspaces) == 2
      assert Enum.all?(realm_names, &(&1 in RealmData.list_realm_names()))
      assert Enum.all?(realm_names, &Database.realm_initialized?/1)
    end
  end

  describe "realms/1" do
    test "creates canonical graph realms" do
      assert RealmHelper.realms(realm_context()).realms == %{
               "realm1" => {%{id: "realm1", name: "realm1", instance_id: "astarte1"}, "astarte1"},
               "realm2" => {%{id: "realm2", name: "realm2", instance_id: "astarte1"}, "astarte1"}
             }
    end
  end

  describe "realm_names/1" do
    test "creates the requested valid and unique names" do
      realm_names =
        RealmHelper.realm_names(%{
          realm_number: 100,
          instances: %{"instance1" => {"instance1", nil}}
        })

      assert length(realm_names) == 100
      assert length(Enum.uniq(realm_names)) == 100
      assert Enum.all?(realm_names, &valid_name?/1)
    end
  end

  defp context do
    [first_realm, second_realm] = unique_realm_ids()

    context = %{} |> InstanceHelper.setup() |> InstanceHelper.data()
    instance_id = context.instance_id

    context
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
    %{
      instances: %{"astarte1" => {"astarte1", nil}},
      realm_names: ["realm1", "realm2"]
    }
  end

  defp unique_realm_ids do
    [
      "realm" <> Integer.to_string(System.unique_integer([:positive])),
      "realm" <> Integer.to_string(System.unique_integer([:positive]))
    ]
  end
end
