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

defmodule Astarte.TestSuite.Helpers.DatabaseTest do
  use ExUnit.Case, async: false
  use Mimic

  import Ecto.Changeset, only: [apply_action!: 2]

  import Astarte.Core.Generators.Interface, only: [interface: 0]
  import Astarte.TestSuite.CaseContext, only: [put!: 5]

  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Repo
  alias Astarte.TestSuite.Helpers.Instance, as: InstanceHelper
  alias Astarte.TestSuite.Helpers.Interface, as: InterfaceHelper
  alias Astarte.TestSuite.Helpers.Realm, as: RealmHelper

  setup :set_mimic_global

  setup do
    Repo
    |> stub(:query!, fn _statement -> :ok end)
    |> stub(:insert!, fn changeset, _opts -> apply_action!(changeset, :insert) end)
    |> stub(:safe_delete_all, fn _query, _opts -> {:ok, 0} end)

    stub(Database, :migrate, fn -> :ok end)

    :ok
  end

  describe "database helpers without a database" do
    test "instance helper records database work" do
      context = instance_context()

      assert context.instance_database_ready?
      assert length(context.instance_keyspaces) == 1
      assert length(context.instance_database_statements) == 1
    end

    test "realm helper records database work" do
      %{
        realms_ready?: realms_ready?,
        realm_keyspaces: realm_keyspaces,
        realm_database_statements: realm_database_statements
      } = realm_context()

      assert realms_ready?
      assert length(realm_keyspaces) == 2
      assert length(realm_database_statements) == 20
    end

    test "interface helper records persistence work" do
      %{
        interfaces_registered?: interfaces_registered?,
        interface_database_results:
          [%{result: {endpoint_result, interface_result}}] = interface_database_results
      } = interface_context()

      assert interfaces_registered?
      assert endpoint_result != []
      assert length(interface_database_results) == 1
      assert length(interface_result) == 2
    end
  end

  defp instance_context do
    %{} |> InstanceHelper.setup() |> InstanceHelper.data()
  end

  defp realm_context do
    [first_realm, second_realm] = unique_realm_ids()
    context = instance_context()
    instance_id = context.instance_id

    context
    |> Map.merge(%{
      realms: %{
        first_realm => {%{id: first_realm, instance_id: instance_id}, instance_id},
        second_realm => {%{id: second_realm, instance_id: instance_id}, instance_id}
      }
    })
    |> RealmHelper.data()
  end

  defp interface_context do
    realm_id = unique_realm_id()
    first_interface = interface() |> Enum.at(0)
    second_interface = interface() |> Enum.at(1)
    context = instance_context()
    instance_id = context.instance_id

    context
    |> Map.put(:realms, %{
      realm_id => {%{id: realm_id, instance_id: instance_id}, instance_id}
    })
    |> RealmHelper.data()
    |> put!(:interfaces, first_interface.name, first_interface, realm_id)
    |> put!(:interfaces, second_interface.name, second_interface, realm_id)
    |> InterfaceHelper.data()
  end

  defp unique_realm_ids, do: [unique_realm_id(), unique_realm_id()]

  defp unique_realm_id do
    "realm" <> Integer.to_string(System.unique_integer([:positive]))
  end
end
